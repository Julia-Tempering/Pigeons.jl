using JSON 
using ZipFile

function post_db_dir() 
    result = Pigeons.mpi_settings_folder() * "/posteriordb/posterior_database"
    if !isdir(result)
        error("run setup_posterior_db() first (this only needs to be done once)")
    end
    return result
end

model_dir() = "$(post_db_dir())/models/stan/"
data_dir() = "$(post_db_dir())/data/data/"
posteriors_dir() = "$(post_db_dir())/posteriors/"

function precompile_all_stan_models(ref_only = true)
    for json_file in posterior_db_list(ref_only)
        log_potential_from_posterior_db(json_file)
    end
end

posterior_db_list(ref_only = true) = filter(it -> !ref_only || has_ref(it), readdir(posteriors_dir()))
read_specs(posterior_json_file) = JSON.parsefile("$(posteriors_dir())/$posterior_json_file")
has_ref(posterior_json_file) = read_specs(posterior_json_file)["reference_posterior_name"] !== nothing

function stan_files(posterior_json_file)
    specs = read_specs(posterior_json_file)
    model_name = specs["model_name"]
    data_name = specs["data_name"]
    data_file = "$(data_dir())/$data_name.json"
    if !isfile(data_file)
        unzip!("$data_file.zip")
    end
    stan_file = "$(model_dir())/$model_name.stan"
    return stan_file, data_file
end

function log_potential_from_posterior_db(posterior_json_file) 
    stan_file, data_file = stan_files(posterior_json_file)
    return StanLogPotential(stan_file, data_file)
end

function setup_posterior_db()
    auto_install_folder = mkpath(Pigeons.mpi_settings_folder())
    repo_name = "posteriordb"
    repo_path = "$auto_install_folder/$repo_name"
    if isdir(repo_path)
        @info "it seems setup_posterior_db() was already ran; to force re-runing, first remove the folder $repo_path"
        return nothing
    end
    cd(auto_install_folder) do # NB: github CI does not allow the test code to clone a repo using git@.., so it has to be over https 
        run(`git clone https://github.com/stan-dev/posteriordb.git`)
    end 
    return nothing
end

function unzip!(file)
    fileFullPath = abspath(file)
    outPath = dirname(fileFullPath)
    zarchive = ZipFile.Reader(fileFullPath)
    for f in zarchive.files
        fullFilePath = joinpath(outPath,f.name)
        if (endswith(f.name,"/") || endswith(f.name,"\\"))
            mkdir(fullFilePath)
        else
            write(fullFilePath, read(f))
        end
    end
    close(zarchive)
end