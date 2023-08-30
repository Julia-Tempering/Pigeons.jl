""" 
$SIGNATURES

The iterim diagnostics computed and printed to 
standard out at the end of every iteration 
(this can be disabled using `show_report = false`).
"""
all_reports() = [  
        # header with    # lambda expression used to 
        # width of 9     # compute that report item
        "  scans   "   => pt -> n_scans_in_round(pt.shared.iterators), 
        " restarts "   => pt -> n_tempered_restarts(pt), 
        "    Λ     "   => pt -> global_barrier(pt.shared.tempering),
        "  Λ_var   "   => pt -> global_barrier_variational(pt.shared.tempering),
        "  time(s) "   => pt -> last_round_max_time(pt), 
        "  allc(B) "   => pt -> last_round_max_allocation(pt), 
        "log(Z₁/Z₀)"   => pt -> stepping_stone(pt),
        "  min(α)  "   => pt -> minimum(swap_prs(pt)), 
        "  mean(α) "   => pt -> mean(swap_prs(pt)),
        "  max|ρ|  "   => pt -> maximum(abs.(energy_ac1s(pt, true))),
        "  mean|ρ| "   => pt -> mean(abs.(energy_ac1s(pt, true))),
        "  min(αₑ) "   => pt -> minimum(explorer_mh_prs(pt)), 
        " mean(αₑ) "   => pt -> mean(explorer_mh_prs(pt)),
    ]

"""
$SIGNATURES 

Report summary information on the progress of [`pigeons()`](@ref).
"""
function report!(pt, prev_header)
    # keep data in DataFrame's for programmatic access
    report_dfs!(pt)

    # show ASCII table as we go for convenience 
    only_one_process(pt) do
        if !pt.inputs.show_report
            return nothing
        end
        reports = reports_available(pt)
        if pt.shared.iterators.round == 1
            header(reports)
        elseif prev_header != header_str(reports) 
            @warn """The set of successful reports changed"""
            header(reports)
        end
        
        println(
            join(
                map(
                    pair -> render_report_cell(pair[2], pt),
                    reports),
                " "
            ))
        if pt.shared.iterators.round == pt.inputs.n_rounds 
            hr(reports, "─")
        end
        return header_str(reports) 
    end
end

render_report_cell(f, pt) = render_report_cell(f(pt))
render_report_cell(value::Number) = @sprintf "%9.3g " value
render_report_cell(value::Tuple{Number, Number}) = 
    "(" * (@sprintf "%4.3g" value[1]) * ", " * (@sprintf "%4.3g" value[2]) * ")"

function header(reports)
    hr(reports, "─")
    println(header_str(reports))
    hr(reports, " ")
end

header_str(reports) = 
    join(
        map(pair -> pair[1], reports), 
        " ")

hr(reports, sep) = 
    println(
        join(
            map(
                pair -> repeat("─", length(pair[1])), 
                reports), 
            sep))
    

function reports_available(pt)
    result = Pair[] 
    for pair in all_reports() 
        try 
            (pair[2])(pt) 
            push!(result, pair)
        catch 
            # some recorder has not been used, skip
        end
    end
    return result
end

macro or_na(expr)
    return quote
        try
            $(esc(expr))
        catch
            missing
        end
    end
end

function report_dfs!(pt) 
    push!(pt.shared.reports.summary, (
            pt.shared.iterators.round,
            n_scans_in_round(pt.shared.iterators), 
            @or_na(n_tempered_restarts(pt)),
            @or_na(global_barrier(pt.shared.tempering)),
            @or_na(global_barrier_variational(pt.shared.tempering)),
            @or_na(last_round_max_time(pt)),
            @or_na(last_round_max_allocation(pt)),
            @or_na(stepping_stone(pt))
    ))

    try 
        dict = value(pt.reduced_recorders.swap_acceptance_pr) 
        for (pair, stat) in dict 
            push!(pt.shared.reports.swap_prs, (
                pt.shared.iterators.round,
                pair[1], 
                pair[2],
                value(stat)
            ))
        end
    catch
    end
end

const OptFloats = Union{Float64, Missing}[]
const OptInts = Union{Int, Missing}[]
init_dfs() = (;
        summary = DataFrame(
            round = Int[],
            n_scans = Int[], 
            n_tempered_restarts = OptInts,
            global_barrier = OptFloats, 
            global_barrier_variational = OptFloats,
            last_round_max_time = OptFloats,
            last_round_max_allocation = OptFloats,
            stepping_stone = OptFloats),
        swap_prs = DataFrame(
            round = Int[], 
            first = Int[], 
            second = Int[],
            mean = Float64[]
        )
    )


