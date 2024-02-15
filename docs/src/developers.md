# Creating a release from a PR

1. Create a new branch locally.
2. Make changes, and **make sure all tests pass locally**.
3. When done, push the branch to the repo and create a PR. **Make sure all tests pass on CI**.
4. Your PR will be reviewed by the team.
5. After the review, but **before merging**, make sure to **bump the version in `Project.toml`**. Follow [this convention](https://juliareach.github.io/JuliaReachDevDocs/latest/release/#Choosing-a-new-release-version).
6. Merge the PR (and possibly delete the branch where you did your work).
7. Navigate to the **merge commit** (**hint**: this should be on the **main** branch!) and make the comment `@JuliaRegistrator register`. [See here for an example](https://github.com/Julia-Tempering/Pigeons.jl/commit/9d7e6e942a7f9194f8e10c46599e871da633f5b1).
8. If all goes well, the bots will take it from here. After the Julia registry merges our release PR, TagBot will create a tag for the release automatically.


# Creating a release without a PR

Do step 7 above with the latest commit on main ([example](https://github.com/Julia-Tempering/Pigeons.jl/commit/f363507f08e60df582750b198b9f49cbd8f5d34a)).

# Running tests

See `test/README.md`.


# Generating documentation

See `docs/README.md`.
