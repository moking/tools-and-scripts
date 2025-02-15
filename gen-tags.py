#!/usr/bin/env python3

import os
import sys
import subprocess

# Define source directory
SRC_DIR = os.getcwd()
# Get directories to exclude from command-line arguments
EXCLUDE_DIRS = set(sys.argv[1:])

def should_exclude(path):
    """Check if the given path should be excluded."""
    return any(path.startswith(os.path.join(SRC_DIR, ex_dir)) for ex_dir in EXCLUDE_DIRS)

def generate_file_list():
    """Find source files and write them to cscope.files, excluding specified directories."""
    file_extensions = (".c", ".h", ".S")  # C, Header, Assembly files
    with open("cscope.files", "w") as cscope_file:
        for root, dirs, files in os.walk(SRC_DIR, topdown=True):
            # Modify 'dirs' in place to prevent traversal into excluded directories
            dirs[:] = [d for d in dirs if not should_exclude(os.path.join(root, d))]
            for file in files:
                if file.endswith(file_extensions):
                    cscope_file.write(os.path.join(root, file) + "\n")

def generate_cscope():
    """Run cscope to generate cscope.out"""
    subprocess.run(["cscope", "-b", "-q", "-k"], check=True)

def generate_ctags():
    """Run ctags to generate tags"""
    subprocess.run(["ctags", "-R", "--languages=C", "--exclude=" + ",".join(EXCLUDE_DIRS)], check=True)

def main():
    """Main function to generate cscope.out and tags"""
    print(f"📂 Scanning '{SRC_DIR}' and skipping: {', '.join(EXCLUDE_DIRS) if EXCLUDE_DIRS else 'None'}")
    generate_file_list()
    print("✅ Generated cscope.files")
    
    print("🔍 Generating cscope.out...")
    generate_cscope()
    print("✅ cscope.out created")
    
    print("🔍 Generating tags...")
    generate_ctags()
    print("✅ tags file created")

if __name__ == "__main__":
    main()

