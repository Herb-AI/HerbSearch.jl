"""
    print_logo()

Prints a stylized ascii art of the word probe.
"""
function print_logo()
    printstyled(raw"""                 _          
                | |         
 _ __  _ __ ___ | |__   ___ 
| '_ \| '__/ _ \| '_ \ / _ \
| |_) | | | (_) | |_) |  __/
| .__/|_|  \___/|_.__/ \___|
| |                         
|_|                       """, color=:magenta, bold=true)
    println()
    println(repeat("=", 80) * "\n")
end