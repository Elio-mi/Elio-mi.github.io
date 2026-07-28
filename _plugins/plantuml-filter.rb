# frozen_string_literal: true

module Jekyll
  module PlantUMLFilter
    # PlantUML's official server supports simple UTF-8 HEX encoding with a `~h`
    # prefix. It keeps the build dependency-free and makes the generated URL
    # deterministic.
    def plantuml_encode(input)
      "~h#{input.to_s.encode(Encoding::UTF_8).unpack1('H*')}"
    end
  end
end

Liquid::Template.register_filter(Jekyll::PlantUMLFilter)
