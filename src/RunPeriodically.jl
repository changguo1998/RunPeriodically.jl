module RunPeriodically

using Dates, TOML

const CHARSET = ['A':'Z'; 'a':'z'; '0':'9']

const START_FLAG_FILE = ".flag.start."
const STOP_FLAG_FILE = ".flag.stop."

struct CommandSetting
    command::Vector{String}
    dir::String
    check_interval::Float64
    run_interval::Float64
    hash::String
end

function CommandSetting(cmd::AbstractVector{<:AbstractString},
    dir::AbstractString=pwd(),
    check_interval::Real=1,
    run_interval::Real=5,
    hash::String=String(rand(CHARSET, 8)))
    tcmd = String.(cmd)
    tdir = String(dir)
    return CommandSetting(tcmd, tdir, check_interval, run_interval, hash)
end

function load_from_file(f::AbstractString)
    t = TOML.parsefile(f)
    return CommandSetting(
        t["command"],
        t["dir"],
        t["check_interval"],
        t["run_interval"],
        t["hash"]
    )
end

function print_to_file(io::IO, cs::CommandSetting)
    d = Dict(
        "command" => cs.command,
        "dir" => cs.dir,
        "check_interval" => cs.check_interval,
        "run_interval" => cs.run_interval,
        "hash" => cs.hash
    )
    TOML.print(io, d)
    return nothing
end

print_to_file(f::AbstractString, cs::CommandSetting) = open(io->print_to_file(io, cs), f, "w")

print_to_file(cs::CommandSetting) = print_to_file(joinpath(cs.dir, "RunPeriodically.$(cs.hash).toml"), cs)

function run_periodically(cs::CommandSetting)
    last_run = now()
    flag_start= joinpath(cs.dir, START_FLAG_FILE * cs.hash)
    flag_stop = joinpath(cs.dir, STOP_FLAG_FILE * cs.hash)
    touch(flag_start)
    while true
        global last_run
        if isfile(flag_stop)
            if isfile(flag_start)
                rm(flag_start)
            end
            rm(flag_stop)
            @info "[$(now())] Get stop signal"
            break
        end
        current_time = now()
        if current_time - last_run < Millisecond(round(Int, cs.run_interval*1000))
            sleep(round(cs.check_interval*1000)*1e-3)
            continue
        end
        last_run  = current_time
        try
            cmd = Cmd(Cmd(cs.command); dir=cs.dir)
            @info "[$(now())] Run command: $cmd"
            run(cmd)
        catch err
            @error err
        end
    end
    return nothing
end

function list_started_loops(d::AbstractString)
    if !isdir(d)
        return String[]
    end
    start_flag_files = filter(startswith(START_FLAG_FILE), readdir(d))
    return map(f->String(replace(f, START_FLAG_FILE=>"")), start_flag_files)
end

function stop_loop(h::AbstractString, dir::AbstractString=pwd())
    touch(joinpath(dir, STOP_FLAG_FILE * h))
    @info "[$(now())] Waiting for stop of $h"
    while isfile(joinpath(dir, STOP_FLAG_FILE * h))
        sleep(0.5)
    end
    @info "[$(now())] Loop $h stopped"
    return nothing
end

end
