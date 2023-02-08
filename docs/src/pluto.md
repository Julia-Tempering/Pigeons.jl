# Instructions for remote Pluto execution

On the server:

```
julia
using Pluto
Pluto.run(port = 1234)
```

On the client:

```
ssh sockeye -N -L 1234:localhost:1234
```

Open a browser in the client and go to
[http://localhost:1234/](http://localhost:1234/). 
Look at the server terminal to get the "secret" part 
of the URL. 