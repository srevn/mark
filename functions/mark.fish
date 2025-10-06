function __mark_usage
    echo 'Usage:'
    echo ' mark (BOOKMARK|PATH)        Go to directory or open file in $EDITOR'
    echo ' $(mark BOOKMARK)            Get path to BOOKMARK (for command substitution)'
    echo ' mark add [BOOKMARK] [DEST]  Create a BOOKMARK for DEST (file or directory)'
    echo '                                 Default BOOKMARK: name of current directory'
    echo '                                 Default DEST: path to current directory'
    echo ' mark add DEST               Create a bookmark for DEST'
    echo ' mark ls                     List all bookmarks'
    echo ' mark mv OLD NEW             Change the name of a bookmark from OLD to NEW'
    echo ' mark rm BOOKMARK            Remove BOOKMARK'
    echo ' mark clean                  Remove bookmarks that have a missing destination'
    echo ' mark help                   Show this message'
    echo
    echo "Bookmarks are stored in: $MARK_DIR"
    echo 'To change, run: set -U MARK_DIR <dir>'
    return 1
end

function __mark_dir
    if set -q MARK_DIR; and test -n "$MARK_DIR"
        echo $MARK_DIR
        return
    end

    set -U MARK_DIR $HOME/.local/share/mark
    echo $MARK_DIR
end

function __mark_bm_path
    echo (__mark_dir)/$argv
end

function __mark_resolve
    readlink (__mark_bm_path $argv) 2>/dev/null
end

function __mark_print
    __mark_resolve $argv | string replace -r "^$HOME" '~' | string replace -r '^~$' $HOME
end

function __mark_ls
    for l in (__mark_dir)/*
        test -L $l; or continue
        basename $l
    end
end

function __mark_rm
    command rm -v (__mark_bm_path $argv[1]); or return $status
    __mark_update_bookmark_completions
end

function __mark_add -a bm dest
    if test -z $bm
        set dest (pwd)
        set bm (basename $dest)
    else
        if test -n $dest
            set dest (realpath $dest)
        else
            if string match -q '*/*' $bm && test -d $bm
                set dest (realpath $bm)
                set bm (basename $dest)
            else
                set dest (pwd)
            end
        end
    end

    if __mark_resolve $bm >/dev/null
        echo "ERROR: Bookmark exists: $bm -> "(__mark_print $bm) >&2
        return 1
    end

    if not test -e $dest
        echo "ERROR: Destination does not exist: $dest" >&2
        return 1
    end

    if string match -q '*/*' $bm
        echo "ERROR: Bookmark name cannot contain '/': $bm" >&2
        return 1
    end

    command ln -s $dest (__mark_bm_path $bm); or return $status

    echo $bm "->" (__mark_print $bm)

    __mark_update_bookmark_completions
end

function __mark_complete_directories
    set -l cl (commandline -ct | string split -m 1 /)
    set -l bm $cl[1]
    set -l bmdir (__mark_resolve $bm)
    if test -z $bmdir
        __fish_complete_directories
    else
        set -e cl[1]
        if test -z $cl
            __fish_complete_directories $bmdir/ | string replace -r 'Directory$' $bm
        else
            __fish_complete_directories $bmdir/$cl | string replace -r 'Directory$' $bm
        end
    end
end

function __mark_update_bookmark_completions
    complete -e -c mark
    complete -c mark -k -x -s h -l help -d 'Show help'

    complete -c mark -k -n __fish_use_subcommand -f -a help -d 'Show help'
    complete -c mark -k -n __fish_use_subcommand -x -a clean -d 'Remove bad bookmarks'
    complete -c mark -k -n __fish_use_subcommand -x -a mv -d 'Rename bookmark'
    complete -c mark -k -n __fish_use_subcommand -x -a rm -d 'Remove bookmark'
    complete -c mark -k -n __fish_use_subcommand -f -a ls -d 'List bookmarks'
    complete -c mark -k -n __fish_use_subcommand -x -a add -d 'Create bookmark'

    complete -c mark -k -n __fish_use_subcommand -r -a '(__mark_complete_directories)'

    for bm in (__mark_ls | sort -r)
        if test -z $bm
            continue
        end
        set -l desc (__mark_print $bm)
        if test -z $desc
            set desc '(broken)'
        end

        complete -c mark -k -n '__fish_use_subcommand; or __fish_seen_subcommand_from rm mv' -r -a (echo $bm | string escape) -d $desc
    end
end

function mark -d 'Bookmarking tool'
    set -l dir (__mark_dir)

    if not test -d $dir
        if command mkdir -p $dir
            echo "Created bookmark directory: $dir"
        else
            echo "Failed to create bookmark directory: $dir"
            return 1
        end
    end

    set -l cmd $argv[1]
    set -l numargs (count $argv)
    switch $cmd
        case ls help clean
            if not test $numargs -eq 1
                echo "Usage: mark $cmd"
                return 1
            end

        case rm
            if not test $numargs -eq 2
                echo "Usage: mark $cmd BOOKMARK"
                return 1
            end

        case add
            if not test $numargs -ge 1 -a $numargs -le 3
                echo 'Usage: mark add [BOOKMARK] [DEST]'
                echo '       mark add DEST'
                return 1
            end

        case mv
            if not test $numargs -eq 3
                echo 'Usage: mark mv OLD NEW'
                return 1
            end
    end

    switch $cmd
        case add
            __mark_add $argv[2..-1]
            return $status

        case rm
            __mark_rm $argv[2]
            return $status

        case ls
            for bm in (__mark_ls)
                echo "$bm -> "(__mark_print $bm)
            end
            return 0

        case mv
            set -l old $argv[2]
            if not __mark_resolve $old >/dev/null
                echo "ERROR: Bookmark not found: $old"
                return 1
            end

            set -l new $argv[3]
            __mark_add $new (__mark_resolve $old); or return $status
            __mark_rm $old; or return $status

            return 0

        case clean
            for bm in (__mark_ls)
                if not test -e (__mark_resolve $bm)
                    __mark_rm $bm
                end
            end
            return 0

        case -h --help help
            __mark_usage
            return 0

        case '*'
            set -l name $argv[1]
            if test -z $name
                __mark_usage
                return 1
            end

            set -l dest (__mark_resolve $name)
            if test -z $dest
                if test -e $name
                    if isatty stdout
                        if test -d $name
                            echo cd (string escape $name) | source -
                        else if test -f $name
                            set -l editor $EDITOR
                            test -n "$editor"; or set editor vi
                            command $editor $name
                        end
                    else
                        realpath $name
                    end
                else
                    echo "mark: No such bookmark or path: "$name"" >&2
                    return 1
                end
            else if test -e $dest
                if isatty stdout
                    if test -d $dest
                        echo cd (string escape $dest) | source -
                    else if test -f $dest
                        set -l editor $EDITOR
                        test -n "$editor"; or set editor vi
                        command $editor $dest
                    end
                else
                    echo $dest
                end
            else
                echo "mark: Destination for bookmark "$name" does not exist: $dest" >&2
                return 1
            end
    end
end
