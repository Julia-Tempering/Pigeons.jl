# A recorder which is skipped in checks.jl, e.g. timing info and alloc
@auto struct NonReproducible
    contents
end

Base.empty!(recorder::NonReproducible) = empty!(recorder.contents)
Base.merge(recorder1::NonReproducible, recorder2::NonReproducible) = 
    NonReproducible(merge(recorder1.contents, recorder2.contents))
record!(recorder::NonReproducible, value) = record!(recorder.contents, value)

