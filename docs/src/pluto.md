# Instructions for remote Pluto execution

Simplest method: connect to server via VSCode. Then 

```
julia
using Pluto
Pluto.run()
```

And this will open a browser window. 

Longer route without VSCode:

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

# Various tricks

## Killing zombies

On the client:

```
lsof -i :1234
```

## Force reload a cell

Ctrl-a followed by Shift-Enter


## Misc

### TableOfContents()

### Wider:

```
html"""<style>
main {
    max-width: 1000px;
}
"""
```

### Sharing github hosted html

https://raw.githack.com/
