#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "optparse"
require "pathname"
require "tmpdir"
require "uri"

ROOT = Pathname.new(__dir__).parent.expand_path
POSTS_GLOB = ROOT.join("_posts", "**", "*.md").to_s
OUTPUT_ROOT = ROOT.join("assets", "img", "remote")
MANIFEST_PATH = ROOT.join("tools", "remote-image-manifest.json")

MARKDOWN_IMAGE_URL = /(?<prefix>!\[[^\]]*\]\()(?<url>https?:\/\/[^\s)]+)(?=[\s)])/i
HTML_IMAGE_URL = /(?<prefix><img\b[^>]*\bsrc=["'])(?<url>https?:\/\/[^"']+)(?<suffix>["'])/i
MARKDOWN_LOCAL_IMAGE_URL = /!\[[^\]]*\]\((?<url>\/assets\/img\/[^\s)]+)(?=[\s)])/i
HTML_LOCAL_IMAGE_URL = /<img\b[^>]*\bsrc=["'](?<url>\/assets\/img\/[^"']+)["']/i

options = {
  dry_run: false,
  verify: false,
  rewrite: true,
  workers: 8,
  timeout: 45,
  max_bytes: 25 * 1024 * 1024
}

OptionParser.new do |parser|
  parser.banner = "Usage: ruby tools/localize_remote_images.rb [options]"

  parser.on("--dry-run", "Only inventory remote image URLs") do
    options[:dry_run] = true
  end

  parser.on("--verify", "Verify the manifest, files, hashes, and local references") do
    options[:verify] = true
  end

  parser.on("--no-rewrite", "Download images without changing Markdown files") do
    options[:rewrite] = false
  end

  parser.on("--workers NUMBER", Integer, "Concurrent downloads (default: 8)") do |value|
    options[:workers] = value
  end

  parser.on("--timeout SECONDS", Integer, "Per-download timeout (default: 45)") do |value|
    options[:timeout] = value
  end

  parser.on("--max-mb NUMBER", Integer, "Maximum accepted image size (default: 25)") do |value|
    options[:max_bytes] = value * 1024 * 1024
  end
end.parse!

abort "workers must be greater than zero" unless options[:workers].positive?
abort "timeout must be greater than zero" unless options[:timeout].positive?
abort "max-mb must be greater than zero" unless options[:max_bytes].positive?

def extract_remote_image_urls(content)
  urls = []
  content.scan(MARKDOWN_IMAGE_URL) { urls << Regexp.last_match[:url] }
  content.scan(HTML_IMAGE_URL) { urls << Regexp.last_match[:url] }
  urls
end

def extract_local_image_urls(content)
  urls = []
  content.scan(MARKDOWN_LOCAL_IMAGE_URL) { urls << Regexp.last_match[:url] }
  content.scan(HTML_LOCAL_IMAGE_URL) { urls << Regexp.last_match[:url] }
  urls
end

def load_manifest
  return { "version" => 1, "images" => {}, "failures" => {} } unless MANIFEST_PATH.exist?

  JSON.parse(MANIFEST_PATH.read)
rescue JSON::ParserError => error
  abort "Cannot parse #{MANIFEST_PATH.relative_path_from(ROOT)}: #{error.message}"
end

def image_type(path)
  header = File.binread(path, 64)
  stripped = File.binread(path, [File.size(path), 4096].min).lstrip

  return ["png", "image/png"] if header.start_with?("\x89PNG\r\n\x1A\n".b)
  return ["jpg", "image/jpeg"] if header.start_with?("\xFF\xD8\xFF".b)
  return ["gif", "image/gif"] if header.start_with?("GIF87a", "GIF89a")
  return ["webp", "image/webp"] if header.start_with?("RIFF") && header.byteslice(8, 4) == "WEBP"
  return ["bmp", "image/bmp"] if header.start_with?("BM")
  return ["ico", "image/x-icon"] if header.start_with?("\x00\x00\x01\x00".b)
  return ["tiff", "image/tiff"] if header.start_with?("II*\x00", "MM\x00*")
  return ["avif", "image/avif"] if header.byteslice(4, 8)&.match?(/\Aftyp(?:avif|avis)/)
  return ["svg", "image/svg+xml"] if stripped.match?(/\A(?:<\?xml[^>]*>\s*)?<svg[\s>]/i)

  nil
end

def safe_host(url)
  URI.parse(url).host.to_s.downcase.gsub(/[^a-z0-9.-]+/, "-").sub(/\A-+/, "").sub(/-+\z/, "")
rescue URI::InvalidURIError
  "unknown-host"
end

def download_image(url, timeout:, max_bytes:)
  Dir.mktmpdir("elio-remote-image-") do |directory|
    temporary_path = File.join(directory, "download")
    command = [
      "curl",
      "-L",
      "--max-time", timeout.to_s,
      "--connect-timeout", [timeout, 15].min.to_s,
      "--retry", "2",
      "--retry-delay", "1",
      "--retry-all-errors",
      "--fail",
      "--silent",
      "--show-error",
      "--user-agent", "ElioBlogImageLocalizer/1.0",
      "--output", temporary_path,
      url
    ]

    _stdout, stderr, status = Open3.capture3(*command)
    raise "curl failed: #{stderr.strip}" unless status.success?
    raise "download produced no file" unless File.file?(temporary_path)

    size = File.size(temporary_path)
    raise "empty response" if size.zero?
    raise "image is larger than #{max_bytes} bytes" if size > max_bytes

    detected = image_type(temporary_path)
    raise "response is not a supported image" unless detected

    extension, content_type = detected
    sha256 = Digest::SHA256.file(temporary_path).hexdigest
    relative_path = Pathname.new("assets")
      .join("img", "remote", safe_host(url), "#{sha256[0, 24]}.#{extension}")
    absolute_path = ROOT.join(relative_path)

    FileUtils.mkdir_p(absolute_path.dirname)
    FileUtils.cp(temporary_path, absolute_path) unless absolute_path.exist?

    {
      "local_path" => "/#{relative_path}",
      "sha256" => sha256,
      "bytes" => size,
      "content_type" => content_type
    }
  end
end

def reusable_entry(entry)
  return nil unless entry.is_a?(Hash)
  return nil unless entry["local_path"] && entry["sha256"]

  path = ROOT.join(entry["local_path"].sub(%r{\A/}, ""))
  return nil unless path.file?
  return nil unless Digest::SHA256.file(path).hexdigest == entry["sha256"]

  entry
end

def rewrite_content(original, replacements)
  replaced_references = 0
  updated = original.gsub(MARKDOWN_IMAGE_URL) do
    match = Regexp.last_match
    replacement = replacements[match[:url]]
    if replacement
      replaced_references += 1
      "#{match[:prefix]}#{replacement}"
    else
      match[0]
    end
  end

  updated = updated.gsub(HTML_IMAGE_URL) do
    match = Regexp.last_match
    replacement = replacements[match[:url]]
    if replacement
      replaced_references += 1
      "#{match[:prefix]}#{replacement}#{match[:suffix]}"
    else
      match[0]
    end
  end

  [updated, replaced_references]
end

def rewrite_remote_images(files, replacements)
  changed_files = 0
  replaced_references = 0

  files.each do |file|
    original = File.read(file)
    updated, replacements_in_file = rewrite_content(original, replacements)
    replaced_references += replacements_in_file

    next if updated == original

    File.write(file, updated)
    changed_files += 1
  end

  [changed_files, replaced_references]
end

def verify_localized_images(files)
  manifest = load_manifest
  images = manifest.fetch("images", {})
  failures = manifest.fetch("failures", {})
  errors = []

  images.each do |url, entry|
    errors << "invalid manifest entry: #{url}" unless reusable_entry(entry)
  end

  local_references = []
  remote_references = []
  files.each do |file|
    content = File.read(file)
    extract_local_image_urls(content).each { |url| local_references << [file, url] }
    extract_remote_image_urls(content).each { |url| remote_references << [file, url] }
  end

  local_references.each do |file, url|
    path = ROOT.join(url.sub(%r{\A/}, ""))
    errors << "missing local image: #{file}: #{url}" unless path.file?
  end

  errors.concat(failures.map { |url, message| "recorded failure: #{url} (#{message})" })

  puts "Manifest images: #{images.size}"
  puts "Manifest failures: #{failures.size}"
  puts "Local image references: #{local_references.size}"
  puts "Remote image references: #{remote_references.size}"
  puts "Verification errors: #{errors.size}"
  errors.first(50).each { |error| warn error }

  errors.empty? && remote_references.empty?
end

post_files = Dir.glob(POSTS_GLOB).sort

if options[:verify]
  exit(verify_localized_images(post_files) ? 0 : 1)
end

references = Hash.new { |hash, key| hash[key] = [] }

post_files.each do |file|
  extract_remote_image_urls(File.read(file)).each do |url|
    references[url] << Pathname.new(file).relative_path_from(ROOT).to_s
  end
end

puts "Scanned #{post_files.size} Markdown files."
puts "Found #{references.values.sum(&:size)} references to #{references.size} unique remote images."

if options[:dry_run]
  hosts = references.keys.group_by { |url| safe_host(url) }
  hosts.sort.each { |host, urls| puts format("%4d  %s", urls.size, host) }
  exit
end

if references.empty?
  puts "No remote image references remain. Nothing to do."
  exit
end

manifest = load_manifest
existing_images = manifest.fetch("images", {})
successes = {}
failures = {}
queue = Queue.new
references.each_key { |url| queue << url }

mutex = Mutex.new
completed = 0
workers = Array.new([options[:workers], references.size].min) do
  Thread.new do
    loop do
      url = queue.pop(true)
      entry = reusable_entry(existing_images[url])
      source = "reused"

      unless entry
        source = "downloaded"
        entry = download_image(
          url,
          timeout: options[:timeout],
          max_bytes: options[:max_bytes]
        )
      end

      mutex.synchronize do
        successes[url] = entry
        completed += 1
        puts format("[%3d/%3d] %-10s %s", completed, references.size, source, url)
      end
    rescue ThreadError
      break
    rescue StandardError => error
      mutex.synchronize do
        failures[url] = error.message
        completed += 1
        warn format("[%3d/%3d] failed     %s (%s)", completed, references.size, url, error.message)
      end
    end
  end
end
workers.each(&:join)

replacements = successes.transform_values { |entry| entry["local_path"] }
changed_files = 0
replaced_references = 0
if options[:rewrite]
  changed_files, replaced_references = rewrite_remote_images(post_files, replacements)
end

all_images = existing_images.merge(successes).sort.to_h
all_failures = manifest.fetch("failures", {}).merge(failures)
successes.each_key { |url| all_failures.delete(url) }

manifest = {
  "version" => 1,
  "images" => all_images,
  "failures" => all_failures.sort.to_h
}
MANIFEST_PATH.write("#{JSON.pretty_generate(manifest)}\n")

remaining_references = post_files.sum do |file|
  extract_remote_image_urls(File.read(file)).size
end

unique_local_paths = successes.values.map { |entry| entry["local_path"] }.uniq
localized_bytes = unique_local_paths.sum do |path|
  absolute_path = ROOT.join(path.sub(%r{\A/}, ""))
  absolute_path.file? ? absolute_path.size : 0
end

puts
puts "Downloaded or reused: #{successes.size}"
puts "Failed: #{failures.size}"
puts "Changed Markdown files: #{changed_files}"
puts "Replaced references: #{replaced_references}"
puts "Remaining remote references: #{remaining_references}"
puts "Unique localized files in this run: #{unique_local_paths.size}"
puts format("Localized size in this run: %.2f MiB", localized_bytes / 1024.0 / 1024.0)
puts "Manifest: #{MANIFEST_PATH.relative_path_from(ROOT)}"

exit 1 unless failures.empty?
