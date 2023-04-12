all_reports() = [  
        # header with    # lambda expression used to 
        # width of 9     # compute that report item
        "  #scans  "   => pt -> n_scans_in_round(pt.shared.iterators), 
        "  rd-trip "   => pt -> n_round_trips(pt), 
        "    Λ     "   => pt -> pt.shared.tempering.communication_barriers.globalbarrier, 
        "    Λt    "   => pt -> global_barrier_trapezoid(pt), 
        "    Λis   "   => pt -> global_barrier_is(pt), 
        "  time(s) "   => pt -> last_round_max_time(pt), 
        "  allc(B) "   => pt -> last_round_max_allocation(pt), 
        "  log(Z)  "   => pt -> stepping_stone(pt),
        "  min(α)  "   => pt -> minimum(swap_prs(pt)), 
        "  mean(α) "   => pt -> mean(swap_prs(pt)),
        "  max|ρ|  "   => pt -> maximum(abs.(energy_ac1s(pt, true))),
        "  mean|ρ| "   => pt -> mean(abs.(energy_ac1s(pt, true))),
    ]

"""
$SIGNATURES 

Report summary information on the progress of [`pigeons()`](@ref).
"""
report(pt) = only_one_process(pt) do
    reports = reports_available(pt)
    if pt.shared.iterators.round == 1
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
end

render_report_cell(f, pt) = render_report_cell(f(pt))
render_report_cell(value::Number) = @sprintf "%9.3g " value

function header(reports)
    hr(reports, "─")
    println(
        join(
            map(pair -> pair[1], reports), 
            " "))
    hr(reports, " ")
end

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