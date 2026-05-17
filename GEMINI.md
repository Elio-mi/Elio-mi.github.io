# Note Creator Skill

This skill allows Gemini CLI to create new blog posts following the Chirpy theme conventions established in this repository.

## Standards & Conventions

### 1. File Location
- Posts MUST be placed in the `_posts/` directory.
- Posts SHOULD be organized into subdirectories by category (e.g., `_posts/Linux/`, `_posts/数据结构/`).
- If a category subdirectory does not exist, create it.

### 2. Naming Convention
- Filename format: `YYYY-MM-DD-title.md`
- Use the current date for `YYYY-MM-DD`.
- The `title` part of the filename should be descriptive and can include Chinese characters to match existing patterns.

### 3. Front Matter
Every post MUST start with YAML front matter:
```yaml
---
title: <post_title>
date: YYYY-MM-DD HH:MM:SS +0800
categories: [<category_name>]
tags: [<tag1>, <tag2>]
---
```
- `title`: The display title of the post.
- `date`: The current date and time (use `+0800` timezone as per existing posts).
- `categories`: An array of category names. The primary category should match the subdirectory name.
- `tags`: An array of relevant tags.

### 4. Content Structure
- Start with an `# H1` header that matches the `title`.
- Use Markdown for the content.
- For technical posts (like LeetCode solutions), include sections like "题目链接", "思路", and "代码".

## Workflow: Create Note

1. **Research:** 
   - Identify the topic, category, and tags.
   - Check if the category directory exists in `_posts/`.
2. **Strategy:** 
   - Define the target file path: `_posts/<Category>/YYYY-MM-DD-<title>.md`.
   - Prepare the front matter with the current timestamp.
3. **Execution:**
   - Create the subdirectory if needed.
   - Write the file with the appropriate front matter and initial content.
4. **Validation:**
   - Verify the file exists.
   - (Optional) Run `bundle exec jekyll build` or `tools/test.sh` if available to check for YAML errors.
