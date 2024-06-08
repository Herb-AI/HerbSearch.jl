function colored_rgb(r, g, b, t)
    "\e[1m\e[38;2;$r;$g;$b;249m" * t
end
function colored(t; color)
    color_code = Dict(
        :red => [255, 0, 0],
        :green => [0, 255, 0],
        :blue => [0, 0, 255],
        :yellow => [255, 255, 0],
        :magenta => [255, 0, 255],
        :cyan => [0, 255, 255],
        :white => [255, 255, 255],
        :black => [0, 0, 0]
    )
    r, g, b = color_code[color]
    colored_rgb(r, g, b, t)
end

function create_latex_plot_text(data, cycle_length)
    latex_coord_data = replace(repr(data), "), " => ")\n", '[' => '{' , ']' => '}')
    format_string = """
     \\addplot[
        line width=2pt
     ]
        coordinates $latex_coord_data
      ;
     \\addlegendentry{Reward Cycle length $cycle_length }"""
    
    open("graph.tex","a") do f 
        write(f, format_string)
    end
end