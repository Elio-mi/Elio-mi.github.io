#!/usr/bin/env python3
"""
修复 Jekyll 构建验证错误
- 清理无效的图片路径（Windows 绝对路径、HTML 注释、data URI）
- 修复 HTTP 链接为 HTTPS
- 清理无效的图片引用
"""

import os
import re
from pathlib import Path

POSTS_DIR = "_posts"

def fix_invalid_image_paths(content):
    """修复无效的图片路径"""
    # 1. 移除 HTML img 标签中的 Windows 绝对路径
    # <img src="C:\Users\..."> -> 移除整个标签
    content = re.sub(
        r'<img\s+src=["\']C:\\[^"\']+["\'][^>]*>',
        '<!-- 图片已移除：Windows 绝对路径无法访问 -->',
        content
    )
    
    # 2. 移除 Markdown 图片格式中的 HTML 注释路径
    # ![alt](<!-- 原始路径: ... -->) -> 移除整个图片引用
    content = re.sub(
        r'!\[([^\]]*)\]\(<!--[^>]+-->\)',
        r'<!-- 图片已移除：\1 -->',
        content
    )
    
    # 3. 移除无效的 data URI 图片
    # ![alt](data:image/...) -> 移除
    content = re.sub(
        r'!\[([^\]]*)\]\(data:image/[^)]+\)',
        r'<!-- 图片已移除：\1 (data URI) -->',
        content
    )
    
    # 4. 移除 HTML 注释中的图片路径（单独一行的情况）
    # <!-- 原始路径: C:\... --> -> 移除
    content = re.sub(
        r'<!--\s*原始路径:\s*[^>]+-->\s*\n?',
        '',
        content
    )
    
    # 5. 修复 HTML 注释中的图片路径（在 img 标签中的情况）
    # <img ...><!-- 原始路径: ... --> -> 移除注释部分
    content = re.sub(
        r'(<img[^>]+>)\s*<!--[^>]+原始路径[^>]+-->',
        r'\1',
        content
    )
    
    return content

def fix_http_links(content):
    """修复 HTTP 链接为 HTTPS"""
    # cplusplus.com
    content = re.sub(
        r'http://www\.cplusplus\.com',
        'https://www.cplusplus.com',
        content
    )
    content = re.sub(
        r'http://cplusplus\.com',
        'https://www.cplusplus.com',
        content
    )
    
    # oj.ecustacm.cn - 检查是否支持 HTTPS，如果不支持则保持 HTTP
    # 先尝试替换，如果网站不支持 HTTPS，可以在 CI 配置中忽略
    # content = re.sub(
    #     r'http://oj\.ecustacm\.cn',
    #     'https://oj.ecustacm.cn',
    #     content
    # )
    
    return content

def fix_invalid_links(content):
    """修复无效的链接"""
    # 修复缺失 href 的 <a> 标签
    # <a>text</a> -> 移除标签，保留文本
    content = re.sub(
        r'<a(?:\s+[^>]*)?>(.*?)</a>',
        r'\1',
        content
    )
    
    # 修复缺失引用的链接（如果 href 为空或无效）
    content = re.sub(
        r'<a\s+href=["\']?["\']?\s*>(.*?)</a>',
        r'\1',
        content
    )
    
    return content

def process_file(file_path):
    """处理单个文件"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # 应用所有修复
        content = fix_invalid_image_paths(content)
        content = fix_http_links(content)
        content = fix_invalid_links(content)
        
        # 如果内容有变化，写回文件
        if content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        
        return False
    except Exception as e:
        print(f"✗ 处理文件失败 {file_path}: {e}")
        return False

def main():
    """主函数"""
    print("=" * 50)
    print("修复 Jekyll 构建验证错误")
    print("=" * 50)
    
    if not os.path.exists(POSTS_DIR):
        print(f"✗ 错误: {POSTS_DIR} 目录不存在")
        return
    
    # 查找所有 Markdown 文件
    md_files = []
    for root, dirs, files in os.walk(POSTS_DIR):
        for file in files:
            if file.endswith('.md'):
                md_files.append(os.path.join(root, file))
    
    print(f"\n找到 {len(md_files)} 个 Markdown 文件")
    print("开始处理...")
    print("-" * 50)
    
    fixed_count = 0
    for md_file in md_files:
        if process_file(md_file):
            print(f"✓ 修复: {os.path.relpath(md_file, POSTS_DIR)}")
            fixed_count += 1
    
    print("\n" + "=" * 50)
    print(f"修复完成! 共修复 {fixed_count} 个文件")
    print("=" * 50)

if __name__ == "__main__":
    main()
