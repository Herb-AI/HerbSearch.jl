"""
    print_logo_probe()

Prints a stylized ascii art of the word probe.
"""
function print_logo_probe()
    printstyled(raw"""______          _                __ ___  ____           ______ _     
| ___ \        | |              / / |  \/  (_)          | ___ \ |    
| |_/ / __ ___ | |__   ___     / /  | .  . |_ _ __   ___| |_/ / |    
|  __/ '__/ _ \| '_ \ / _ \   / /   | |\/| | | '_ \ / _ \    /| |    
| |  | | | (_) | |_) |  __/  / /    | |  | | | | | |  __/ |\ \| |____
\_|  |_|  \___/|_.__/ \___| /_/     \_|  |_/_|_| |_|\___\_| \_\_____/
                                                                     
                                                                     """, color=:magenta, bold=true)
    println()
    println(repeat("=", 80) * "\n")
end