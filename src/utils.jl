"""
    @timed_exec(seconds, expr::Expr)

Executes `expr` for maximally `seconds` seconds

Example:
    @timed_exec 2 begin 
        println("start")
        sleep(5)
        println("stop")
    end

    
"""
macro timed_exec(seconds, expr::Expr)
    return quote
        tsk = @async $(esc(expr))

        Timer($seconds) do timer
            istaskdone(tsk) || Base.throwto(tsk, InterruptException())
        end

        try
            fetch(tsk)
        catch _
            nothing
        end
    end
end

"""
    @timedfor(var_iter_expr::Expr, body_expr::Expr, seconds::Int64)

Implements an iterator that is allowed to iterator for maximally `seconds` seconds.
For all practical purposes, this iterator acts as a for loop that checks whether the iteration is taking more time than permitted after processing every element.

Example:
    @timedfor i in [1,2,3] begin
        println(i+1)
        sleep(2)
    end 3
"""
macro timedfor(var_iter_expr::Expr, body_expr::Expr, seconds::Int64)
    should_end_at = time() + seconds
    loop_var = var_iter_expr.args[2]
    loop_iter = var_iter_expr.args[3]
    quote
        next = @timed_exec $seconds iterate($loop_iter) 

        while next != nothing
            # process the element
            $(esc(loop_var)) =  next[1]
            $(esc(body_expr))

            if time() > $should_end_at
                #if we are out of time, stop
                next = nothing
            else
                next = @timed_exec max($should_end_at - time(), 0) iterate($loop_iter, next[2])
            end
        end
    end
end


#@timedfor  i in [1,2,3] begin println(i+1) end 2




# @timed_exec 2 begin
#     println("first")
#     sleep(5)
#     println("second")
#     end

#@timedfor 2 [1,2,3] println(item)


