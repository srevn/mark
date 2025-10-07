function __mark_usage
    echo 'Usage:' >&2
    echo '  mark BOOKMARK                  Navigate to bookmark (directory or file in $VISUAL)' >&2
    echo '  mark PATH                      Create bookmark with basename as name (requires /)' >&2
    echo '  $(mark BOOKMARK)               Get path to BOOKMARK (for command substitution)' >&2
    echo '  mark add [NAME] [DEST]         Create a bookmark NAME for DEST (file or directory)' >&2
    echo '                                   Default NAME: basename of current directory' >&2
    echo '                                   Default DEST: current directory' >&2
    echo '  mark add DEST                  Create a bookmark for DEST (requires /)' >&2
    echo '  mark get BOOKMARK              Print the destination path of BOOKMARK' >&2
    echo '  mark list                      List all bookmarks' >&2
    echo '  mark rename OLD NEW            Change the name of a bookmark from OLD to NEW' >&2
    echo '  mark remove BOOKMARK           Remove BOOKMARK' >&2
    echo '  mark clean                     Remove bookmarks that have a missing destination' >&2
    echo '  mark help                      Show this message' >&2
    echo >&2
    echo "Bookmarks are stored in: $MARK_DIR" >&2
    echo 'To change, run: set -U MARK_DIR <dir>' >&2
    return 1
end

function __mark_validate_dir -a dir
    if test -z "$dir"
        echo "mark: invalid bookmark directory (empty)" >&2
        return 1
    end

    if not string match -q '/*' -- "$dir"
        echo "mark: bookmark directory must be absolute path: '$dir'" >&2
        return 1
    end

    if string match -q '*/..' '*/../*' -- "$dir"
        echo "mark: bookmark directory cannot contain '..': $dir" >&2
        return 1
    end

    return 0
end

function __mark_validate_name -a name
    if test -z "$name"
        echo "mark: bookmark name cannot be empty" >&2
        return 1
    end

    if test "$name" = "." -o "$name" = ".."
        echo "mark: bookmark name cannot be '.' or '..'" >&2
        return 1
    end

    if string match -q '*/*' -- "$name"
        echo "mark: bookmark name cannot contain '/': '$name'" >&2
        return 1
    end

    if string match -q -- '-*' "$name"
        echo "mark: bookmark name cannot start with '-': '$name'" >&2
        return 1
    end

    if string match -q -r '\s' -- "$name"
        echo "mark: bookmark name cannot contain whitespace: '$name'" >&2
        return 1
    end

    return 0
end

function __mark_dir
    if set -q MARK_DIR; and test -n "$MARK_DIR"
        echo "$MARK_DIR"
        return
    end

    set -U MARK_DIR "$HOME/.local/share/mark"
    echo "$MARK_DIR"
end

function __mark_bm_path
    echo (__mark_dir)/"$argv"
end

function __mark_resolve
    readlink (__mark_bm_path "$argv") 2>/dev/null
end

function __mark_print
    __mark_resolve "$argv" | string replace -r "^$HOME" '~'
end

function __mark_list
    set -l dir (__mark_dir)
    for l in "$dir"/*
        test -L "$l"; or continue
        basename "$l"
    end
end

function __mark_remove
    if not test -L (__mark_bm_path "$argv[1]")
        echo "mark: bookmark not found: '$argv[1]'" >&2
        return 1
    end

    set -l bm_path (__mark_print "$argv[1]")
    echo "mark: removed bookmark: '$argv[1]' -> $bm_path"

    command rm (__mark_bm_path "$argv[1]"); or return $status
    __mark_update_bookmark_completions
end

function __mark_add
    set -l bm ""
    set -l dest ""

    switch (count $argv)
        case 0
            set dest (pwd)
            set bm (basename "$dest")

        case 1
            set -l arg1 "$argv[1]"
            if string match -q '*/*' -- "$arg1"
                set dest "$arg1"
                set bm (basename "$dest")
            else
                set bm "$arg1"
                set dest (pwd)
            end

        case 2
            set bm "$argv[1]"
            set dest "$argv[2]"

        case '*'
            echo "mark: too many arguments" >&2
            echo 'Usage: mark add [NAME] [DEST]' >&2
            return 1
    end

    set -l resolved (realpath "$dest" 2>/dev/null)
    if test -n "$resolved"
        set dest "$resolved"
    else if not string match -q '/*' -- "$dest"
        set dest (pwd)/"$dest"
    end

    __mark_validate_name "$bm"; or return $status

    if __mark_resolve "$bm" >/dev/null
        echo "mark: bookmark already exists: '$bm' -> "(__mark_print "$bm") >&2
        return 1
    end

    if not test -e "$dest"
        echo "mark: destination does not exist: '$dest'" >&2
        return 1
    end

    command ln -s "$dest" (__mark_bm_path "$bm"); or return $status

    echo "mark: bookmarked: '$bm' -> "(__mark_print "$bm")

    __mark_update_bookmark_completions
end

function __mark_clean
    for bm in (__mark_list)
        set -l dest (__mark_resolve "$bm")
        if test -z "$dest"; or not test -e "$dest"
            set -l bm_path (__mark_bm_path "$bm")
            set -l broken_dest (readlink "$bm_path")

            echo "mark: removed bookmark: '$bm' -> $broken_dest"

            command rm "$bm_path"; or return $status
        end
    end
    __mark_update_bookmark_completions
end

function __mark_complete_directories
    if not string match -q -- '*/*' (commandline -ct)
        return
    end
    set -l cl (commandline -ct | string split -m 1 /)
    set -l bm "$cl[1]"
    set -l bmdir (__mark_resolve "$bm")
    if test -z "$bmdir"
        __fish_complete_directories
    else
        set -e cl[1]
        if test -z "$cl"
            __fish_complete_directories "$bmdir"/ | string replace -r 'Directory$' "$bm"
        else
            __fish_complete_directories "$bmdir"/"$cl" | string replace -r 'Directory$' "$bm"
        end
    end
end

function __mark_update_bookmark_completions
    complete -e -c mark
    complete -c mark -k -x -s h -l help -d 'Show help'

    complete -c mark -k -n __fish_use_subcommand -f -a help -d 'Show help'
    complete -c mark -k -n __fish_use_subcommand -x -a clean -d 'Remove bad bookmarks'
    complete -c mark -k -n __fish_use_subcommand -x -a rename -d 'Rename bookmark'
    complete -c mark -k -n __fish_use_subcommand -x -a remove -d 'Remove bookmark'
    complete -c mark -k -n __fish_use_subcommand -f -a list -d 'List bookmarks'
    complete -c mark -k -n __fish_use_subcommand -x -a get -d 'Get bookmark path'
    complete -c mark -k -n __fish_use_subcommand -x -a add -d 'Create bookmark'

    complete -c mark -k -n __fish_use_subcommand -r -a '(__mark_complete_directories)'

    for bm in (__mark_list | sort -r)
        if test -z "$bm"
            continue
        end
        set -l desc (__mark_print "$bm")
        if test -z "$desc"
            set desc '(broken)'
        end

        complete -c mark -k -n '__fish_use_subcommand; or __fish_seen_subcommand_from get remove rename' -r -a (echo "$bm" | string escape) -d "$desc"
    end
end

function mark -d 'Bookmarking tool'
    set -l dir (__mark_dir)

    __mark_validate_dir "$dir"; or return $status

    if not test -d "$dir"
        if command mkdir -p "$dir"
            echo "mark: created bookmark directory: '$dir'" >&2
        else
            echo "mark: failed to create bookmark directory: '$dir'" >&2
            return 1
        end
    end

    if not test -w "$dir"
        echo "mark: bookmark directory is not writable: '$dir'" >&2
        return 1
    end

    set -l cmd "$argv[1]"
    set -l numargs (count $argv)

    switch "$cmd"
        case add
            if not test "$numargs" -ge 1 -a "$numargs" -le 3
                echo 'mark: usage: mark add [NAME] [DEST]' >&2
                return 1
            end
            __mark_add $argv[2..-1]
            return $status

        case remove
            if not test "$numargs" -eq 2
                echo 'mark: usage: mark remove BOOKMARK' >&2
                return 1
            end
            __mark_remove "$argv[2]"
            return $status

        case list
            if not test "$numargs" -eq 1
                echo 'mark: usage: mark list' >&2
                return 1
            end
            for bm in (__mark_list)
                echo "$bm -> "(__mark_print "$bm")
            end
            return 0

        case get
            if not test "$numargs" -eq 2
                echo 'mark: usage: mark get BOOKMARK' >&2
                return 1
            end
            set -l dest (__mark_resolve "$argv[2]")
            if test -z "$dest"
                echo "mark: no such bookmark: '$argv[2]'" >&2
                return 1
            end
            echo "$dest"
            return 0

        case rename
            if not test "$numargs" -eq 3
                echo 'mark: usage: mark rename OLD NEW' >&2
                return 1
            end
            set -l old "$argv[2]"
            set -l new "$argv[3]"

            if not test -L (__mark_bm_path "$old")
                echo "mark: bookmark not found: '$old'" >&2
                return 1
            end

            __mark_validate_name "$new"; or return $status

            if test -L (__mark_bm_path "$new")
                echo "mark: bookmark already exists: '$new'" >&2
                return 1
            end

            set -l old_path (__mark_print "$old")
            echo "mark: renamed bookmark: '$old' -> '$new' ($old_path)"

            command mv (__mark_bm_path "$old") (__mark_bm_path "$new"); or return $status
            __mark_update_bookmark_completions
            return 0

        case clean
            if not test "$numargs" -eq 1
                echo 'mark: usage: mark clean' >&2
                return 1
            end
            __mark_clean
            return $status

        case -h --help help
            if not test "$numargs" -eq 1
                echo 'mark: usage: mark help' >&2
                return 1
            end
            __mark_usage
            return 0

        case '*'
            set -l name "$argv[1]"
            if test -z "$name"
                __mark_usage
                return 1
            end

            if string match -q '*/*' -- "$name"
                __mark_add (basename "$name") "$name"
                return $status
            end

            set -l dest (__mark_resolve "$name")
            if test -z "$dest"
                echo "mark: no such bookmark: $name" >&2
                return 1
            else if test -e "$dest"
                if isatty stdout
                    if test -d "$dest"
                        echo cd (string escape "$dest") | source -
                    else if test -f "$dest"
                        if set -q VISUAL[1]
                            command $VISUAL "$dest"
                        else if set -q EDITOR[1]
                            command $EDITOR "$dest"
                        else
                            command vi "$dest"
                        end
                    end
                else
                    echo "$dest"
                end
            else
                echo "mark: destination for bookmark '$name' does not exist: $dest" >&2
                return 1
            end
    end
end
