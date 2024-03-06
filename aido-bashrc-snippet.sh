#!/bin/bash
#
# PURPOSE :
#
#       AI do! (aido) & Sudo AI do! (saido) are bash aliases that use a backing function (also included)to execute bash commands that
#       an LLM model has suggested in respose to user's prompt.
#
#       The snippets below can be added to your .bashrc file to provide a handy in-line way to request help from an LLM
#       model if you happen not to have encyclodedic knowledge of bash commands... or have just forgotten the syntax for a particular
#       command and want a very targetted and actionable reminder with no tl;dr.
#
# SAFETY & SECURITY :
#
#       The LLM-suggested bash command is displayed at the command prompt and the user is able to edit it before choosing to execute
#       it by hitting [Enter], or abandon it by hitting [Ctrl-C] or [Ctrl-D]. 
#
#       Nothing is executed without the user's explicit input and consent.
#
#       That being said, this is intended as a proof-of-concept and no safety or security guarantees are made. The user is responsible
#       for the commands they execute. The function uses 'eval' to execute commands, including ones prefixed by 'sudo', which is generally 
#       considered unsafe.
#
# USAGE :
#
#       aido <prompt>
#       saido <prompt>
#
#           - 'aido' calls the function aido_func() with the '-u' user mode switch
#           - 'saido' calls the function aido_func() with the '-a' user mode switch
#           - <prompt> is the prompt to the LLM model requesting a bash command; additional instructions are prepended to it by the function
#
#       Explanation:
#       - The 'aido' alias executes the LLM-provided bash command as a non-root user, and the 'saido' executes it as root.
#       - These aliases hide a backing function 'aido_func()' that includes a switch parameter to specify the user mode ('-a'=admin, '-u'=user).
#       - Note that if the LLM suggests 'sudo .. xyz ...' in its response, the function will strip the 'sudo' out if it is called by 'aido' or leave
#         it in if it is called by 'saido'.
#       - This is clearly a very rudamentary check (see 'SAFETY & SECURITY') and may result in the command not working if it requires root
#         privileges. Also, the user can always add 'sudo' to the command before executing it... again, see 'SAFETY & SECURITY' above!
#       - These risks could be mitigated somewhat by appending '... under the current user' to the prompt for 'aido' and by
#         scanning the user's edited command for 'sudo' before executing it (all of which is not implemented below).
#       - The function as a whole must be run as a non-root user so that the 'aichat' Python package & server can be run as
#         configured in the user's home directory (~/.cargo/bin/aichat), which is why switches are used. It will refuse to run as root.
#
# EXAMPLES :
#
#       aido 'create a new directory called xyz'
#           - the LLM model is asked to provide a bash command to create a new directory to be executed under the current user
#           - possible response: 'mkdir xyz'
#
#       saido 'create a new directory xyz'
#           - the LLM model is asked to provide a bash command to create a new directory, and the command is executed as root because of 
#             the implicit '-a' switch
#           - possible response: 'sudo mkdir xyz'
#
#       aido 'list files in the current directory'
#           - the LLM model is asked to provide a bash command to list files in the current directory
#           - possible response: 'ls'
#
#       [s]aido 'install a package called xyz'
#           - the LLM model is asked to provide a bash command to install the package xyz
#           - possible response: '[sudo] apt-get install xyz'
#
# SET-UP :
#
#       - Add these snippets to your .bashrc file to provide a handy way to request help from a LLM model to formulate bash commands
#         which you can then choose to edit and execute.
#       - Follow instructions provided elsewhere to install the 'aichat' package and the 'ollama' server with anLLM model
#
# DEPENDENCIES :
#
#       - The 'aichat' package is installed in the user's home directory. 'aichat' is a simple wrapper around the 'aichat' Python package that provides
#         chat functionality and a means of abstracting away how the LLM model is being served
#
#             Refer to: https://github.com/sigoden/aichat
#
#       - If a locally-hosted model is required or preffered, the 'ollama' server can be used. Alternatively, any other LLM model server (like LLM Studio)
#         should work, provided it plays nice with 'aichat'. Should a cloud-based solution be preferrable, OpenAI's API can be used, as well as the many
#         alternatives. Again, 'aichat' takes care of the details and therefore drives the available solution space
#
#             E.g., refer to: https://ollama.com, https://github.com/bentoml/OpenLLM, https://h2o.ai/platform/ai-cloud/make/llm-studio
#
# SHORTCOMINGS and CONSTRAINTS :
#
#       - The prompt that is used (see below) to ask the model for bash command may need to be optimized for the specific LLM model being used
#       - Clean-up of the LLM output is basic as implemented and may need to be improved for specific LLM models and to make more robust in general
#       - Only one comand recommendation is provided at a time (no ability to select from alternatives)
#       - No context is maintained between the user's prompt, the LLM's response, and the next user prompt/LLM response (no chaining)
#       - The rejection mechanism to not execute the suggested command is crude (Ctrl-C, etc.) and raises the possibility of the user
#         mistakenly executing a command they did not intend to
#
# TEST COVERAGE and LIMITATIONS :
#
#       - Tested with the ollama server running locally in Ubuntu and using Eric Hartford's dolphin-mixtral-8x7b model
#       - OpenAI GPT-x via API or other cloud hosted LLM models not tested
#       - Very little prompt engineering done to optimize the LLM's response
#
# POSSIBLE ALTERNATIVES:
#
#       - https://github.com/TheR1D/shell_gpt and many more
#

#
# The following are snippets to add to your .bashrc :
#
# ...

### ALIASES
# Add the following code to your .bashrc file to create the 'aido' and 'saido' aliases
alias aido='aido_func aido -u'   # Short for "AI do!" - this alias is used to execute the AI-provided bash command as a non-root user ('-u')
alias saido='aido_func saido -a' # Short for "Sudo AI do!" - this alias is used to execute the AI-provided bash command as root ('-a')
# Note that the alias names are passed in as the first argument so that a bash history entry can be added for the invoking command

# ... miscellaneous .bashrc file contents

### FUNCTION
# Add the following code to your .bashrc file which is used by the 'aido' and 'saido' aliases
function aido_func() {
    local invoking_alias="$1" # The alias that invoked the function
    shift
    local in_str="$1" # The input string to the function (user mode switch + prompt)

    # Check if the function is being run as root and exit if it is
    #   - The function should be run as non-root so that the 'aitchat' (and ollama) package & server
    #     can be run as configured in the user's home directory (~/.cargo/bin/aichat)
    USER_DIR=$(pwd ~)
    if [[ "$USER_DIR" == "/root" ]]; then
        echo "Should not be run from root. Use -a option to have the option of executin the AI-provided bash command as root."
        return 1
    fi

    # Extract the user mode and prompt from the input string
    #   - Only the admin user mode switch '-a' is recognized. Any arbitrary switch can be used for non-sudo mode (e.g., '-u')
    #     but a switch must be present
    in_str=$(echo "$in_str" | xargs)
    local user_mode="${in_str:0:2}"
    local user_prmt="${in_str:3}"
    user_prmt=$(echo "$user_prmt" | xargs)

    # Prefix that was tested for prompting 'aichat' prepended to actual user prompt
    #   - I'm sure improvements can be made to it with some experimentation
    local prmt="for the following prompt output only the bash command in plain text with no explanations, no surrounding quotes, and no markdown or codeblock notation. If multiple commands or scripting is required please output as a single line: how do I $user_prmt"

    # Create commend to run the AI chatbot and get the suggested bash command
    #
    #   - Note: any leading or trailing spaces, backticks etc. are removed from the LLM output (which, despite prompt instructions to the contrary,
    #     may be present in the output, at least with dolphin-mixtral-8x7b)
    COMMAND=$("$USER_DIR"/.cargo/bin/aichat "$prmt")
    COMMAND=$(echo "$COMMAND" | sed 's/^[\` ]*//;s/[\` ]*$//' | awk 'NF {if(seen) printf ";"; seen=1; printf $user_prmt}')
    
    # Adds 'sudo' to the new command if the user mode is '-a' (admin) and it is not already present
    # Removes 'sudo' from the new command if the user mode is '-u' (user) and it is present
    if [[ "$user_mode" == "-a" ]]; then
        # Check if COMMAND starts with 'sudo ' and prepend 'sudo ' if not
        if [[ $COMMAND != sudo\ * ]]; then
            COMMAND="sudo $COMMAND"
        fi
    elif [[ "$user_mode" == "-u" ]]; then
        # If user mode is '-u' and COMMAND starts with 'sudo ', remove 'sudo '
        COMMAND="${COMMAND/#sudo /}"
    fi

    # Manually construct the invoking command and add to history
    local CMD_FOR_HISTORY="$invoking_alias $user_prmt"
    history -s "$CMD_FOR_HISTORY"

    # Display the bash command at the command prompt so the user is able to edit it and/or choose to execute it by hitting [Enter]
    read -e -p "Edit & Execute hitting [Enter]: " -i "$COMMAND" EXECUTE

    # Execute the command
    eval "$EXECUTE"

    # Add the executed command to history
    history -s "$EXECUTE"

    return 0
}
export -f aido_func

# the rest of your .bashrc file ...
