# mark

A bookmarking tool for fish-shell that supports both files and directories.

## Usage

`mark` stores bookmarks in `~/.local/share/mark/`

Use `set -U MARK_DIR <dir>` to change where bookmarks are stored.

```sh
$ mark help
Usage:
  mark BOOKMARK                  Navigate to bookmark (directory or file in $VISUAL)
  mark PATH                      Create bookmark with basename as name (requires /)
  $(mark BOOKMARK)               Get path to BOOKMARK (for command substitution)
  mark add [BOOKMARK] [DEST]     Create a BOOKMARK for DEST (file or directory)
                                   Default BOOKMARK: name of current directory
                                   Default DEST: path to current directory
  mark add DEST                  Create a bookmark for DEST
  mark list                      List all bookmarks
  mark rename OLD NEW            Change the name of a bookmark from OLD to NEW
  mark remove BOOKMARK           Remove BOOKMARK
  mark clean                     Remove bookmarks that have a missing destination
  mark help                      Show this message

Bookmarks are stored in: ~/.local/share/mark
To change, run: set -U MARK_DIR <dir>
```

## Features

- **Directory bookmarks**: Jump to directories with `mark BOOKMARK`
- **File bookmarks**: Open files in `$VISUAL` with `mark BOOKMARK`
- **Quick bookmarking**: Use `mark /path/to/location` to create a bookmark named after the basename
- **Path resolution**: Use `$(mark BOOKMARK)` in command substitution to get the path

## Installation

Run `make`
