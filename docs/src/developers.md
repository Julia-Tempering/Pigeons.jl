# Creating a release

The github actions for `Registrator` and 
`TagBot` are active, so the instructions are 
(see https://juliareach.github.io/JuliaReachDevDocs/latest/release/ for details)

- Make sure you are in a separate branch than main
- Increment the package version in `Project.toml` following the convention in https://juliareach.github.io/JuliaReachDevDocs/latest/release/#Choosing-a-new-release-version 
- Commit and **make sure all tests pass on CI and locally**
- Comment `@JuliaRegistrator register` on the commit/branch you want to register.


# Running tests

See `test/README.md`.


# Generating documentation

See `docs/README.md`.
