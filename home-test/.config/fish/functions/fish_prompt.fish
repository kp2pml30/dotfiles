# based on https://github.com/oh-my-fish/theme-eden/blob/master/LICENSE

function _git_branch_name
   echo (command git symbolic-ref HEAD 2> /dev/null | sed -e 's|^refs/heads/||')
end

function _is_git_dirty
   set resStr (timeout 0.2s git status -s --ignore-submodules=dirty 2> /dev/null)
   set res $status
   if [ $res = 0 ]
       if [ "$resStr" = "" ]
           echo "clean"
       else
           echo "dirty"
       end
   else if [ $res = 124 ]
       echo "?"
   else
       echo "dirty"
   end
end

## Function to show a segment
function _prompt_segment -d "Function to show a segment"
   # Get colors
   set -l bg $argv[1]
   set -l fg $argv[2]

   # Set 'em
   set_color -b $bg
   set_color $fg

   # Print text
   if [ -n "$argv[3]" ]
       echo -n -s $argv[3]
   end

# Reset
   set_color -b normal
   set_color normal

   # Print padding
   if [ (count $argv) = 4 ]
       echo -n -s $argv[4]
   end
end

function show_ssh_status -d "Function to show the ssh tag"
   if test "$THEME_EDEN_HIDE_SSH_TAG" != 'yes'
       if [ -n "$SSH_CLIENT" ]
           if [ (id -u) = "0" ]
               _prompt_segment red white "-SSH-" ' '
           else
               _prompt_segment blue white "-SSH-" ' '
           end
       end
   end
end

function show_host -d "Show host & user name"
   if [ (id -u) = "0" ]
       echo -n (set_color red)
   else
       echo -n (set_color blue)
   end
   echo -n "$USER@"(hostname|cut -d . -f 1)' ' (set color normal)
end

function show_cwd -d "Function to show the current working directory"
   if test "$theme_short_path" != 'yes' -a (prompt_pwd) != '~' -a (prompt_pwd) != '/'
       set -l cwd (dirname (prompt_pwd))
       test $cwd != '/'; and set cwd $cwd'/'
       _prompt_segment normal cyan $cwd
   end
   set_color -o cyan
   echo -n (basename (prompt_pwd))' '
   set_color normal
end

function show_git_info -d "Show git branch and dirty state"
   if [ (_git_branch_name) ]
       set -l git_branch '['(_git_branch_name)']'

       set_color -o
       echo -ne " "
       set dirty (_is_git_dirty)
       switch "$dirty"
           case "clean"
               set_color -o green
               echo -ne "$git_branch "
           case "dirty"
               set_color -o red
               echo -ne "$git_branch× "
           case '*'
               set_color -o yellow
               echo -ne "$git_branch? "
       end
       set_color normal
   end
end

function show_times
   if test $CMD_DURATION -ge 500
       if test $CMD_DURATION -ge 60000
           set -l duration_minutes (math "floor($CMD_DURATION / 60000)")
           set -l duration_seconds (math "round(($CMD_DURATION % 60000) / 1000)")
           printf "%02d:%02d " $duration_minutes $duration_seconds
       else if test $CMD_DURATION -ge 1000
           set -l duration_seconds (math "round($CMD_DURATION / 1000)")
           echo -ns "$duration_seconds""s "
       else
           echo -ns "$CMD_DURATION""ms "
       end
   end
   # Output the current time
   echo -ne (date "+%H:%M:%S")
end

function show_prompt_char -d "Terminate with a nice prompt char"
   echo ""
   echo -n -s $normal '» '
end

function fish_prompt
   set -l code $status
   # use tput to move cursor to line start
   echo -ne (tput cr)

   show_ssh_status
   show_host
   show_cwd
   show_git_info
   show_times

   if test $code != 0
       echo -ns (set_color red) '[' $code ']'
   end
   show_prompt_char
end
