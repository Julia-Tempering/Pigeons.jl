"""
A continuum of log_potential's interpolating between two end-points.

Convention: the continuum is indexed on [0, 1] 
"""
@informal path begin
    interpolate(path, beta) = @abstract
end

