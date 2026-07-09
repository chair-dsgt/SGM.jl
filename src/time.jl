struct SGMTimer
    start::Float64
    limit::Float64
end

function SGMTimer(time_limit::Float64)::SGMTimer
    return SGMTimer(time(), time_limit)
end

struct TimeLimitException <: Exception end

function remaining_time(timer::SGMTimer)::Float64
    elapsed = time() - timer.start
    return timer.limit - elapsed
end

function check_time(timer::SGMTimer)::Nothing
    if remaining_time(timer) <= 0.0
        throw(TimeLimitException())
    end
end