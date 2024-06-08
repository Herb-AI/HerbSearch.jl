"""
    print_logo_frangel()

Prints a stylized ascii art of the word probe.
"""
function print_logo_frangel()
    printstyled(raw"""                           
     _____  ____    ____  ____    ____    ___  _     
    |     ||    \  /    ||    \  /    |  /  _]| |    
    |   __||  D  )|  o  ||  _  ||   __| /  [_ | |    
    |  |_  |    / |     ||  |  ||  |  ||    _]| |___ 
    |   _] |    \ |  _  ||  |  ||  |_ ||   [_ |     |
    |  |   |  .  \|  |  ||  |  ||     ||     ||     |
    |__|   |__|\_||__|__||__|__||___,_||_____||_____|
                                                      """, color=:magenta, bold=true)
    println()
    println(repeat("=", 80) * "\n")
end