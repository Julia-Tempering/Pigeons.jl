function communicationbarrier(rejection, schedule)
    x = schedule
    y = [0; cumsum(rejection)]
    spl = Interpolations.interpolate(x, y, FritschCarlsonMonotonicInterpolation())
    cumulativebarrier(β) = spl(β)
    localbarrier(β) = Interpolations.gradient(spl, β)[1]
    GlobalBarrier = sum(rejection)
    return (localbarrier = localbarrier, cumulativebarrier = cumulativebarrier, GlobalBarrier = GlobalBarrier)
end