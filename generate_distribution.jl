using LinearAlgebra, DelimitedFiles

"""
	generate_distr(authors::Dict{Int64,Any}, n_year::Int64, ppyear::Int64, ρ0::Float64, amin::Int64=40, amax::Int64=60, savefolder::String="")
	generate_distr(n_year::Int64, ppyear::Int64, ρ0::Float64, amin::Int64=40, amax::Int64=60, savefolder::String="")

Generates a synthetic list of authors with random number of publications in a synthetic journal. The rule of attribution of an author to a new journal follows the adapted preferential attachment rule described in [Delabaya and Tyloo, Quant. Sci. Studies (2022)]. 

_INPUT_:\\
`authors`: Dictionary whose keys (Int64) are the authors indices, and values are themselves dictionaries with "String" keys:\\
	- "age": is the academic age of the author;\\
	- "npaper": is the current number of paper of this author in the journal.\\
If the `authors` argument is not given, then it is arbitrarily generated by the function `init_authors`.\\
`n_years`: Number of years over which the generator is run. Namely this is the number of iterations.\\
`ppyear`: Number of papers published each year in the synthetic journal.\\
`ρ0`: Average proportion of papers that are attributed to new authors each year.\\
`amin`: Academic age at which the likelihood of publishing new papers start decreasing.\\
`amax`: Academic age at which the likelihood of publishing new papers vanishes.\\
`savefolder`: Name of the folder where data are saved. The results are saved in a .csv file (`savefolder*/d_######.csv"`) identified by a six-digit number, generated not to overlap with existing ones. The arguments of the script are saved in `savefolder*"/p_######.jl"`. If `savefolder` is an empty string, data are not saved.

_OUTPUT_:\\
`v`: Vector of the number of papers of each author at the end of the process.
"""
function generate_distr(n_year::Int64, ppyear::Int64, ρ0::Float64, amin::Int64=40, amax::Int64=60, save::String="")
	authors = init_authors(ppyear)

	return generate_distr(authors,n_year,ppyear,ρ0,amin,amax,save)
end

function generate_distr(authors::Dict{Int64,Any}, n_year::Int64, ppyear::Int64, ρ0::Float64, amin::Int64=40, amax::Int64=60, save::String="")
	for y in 1:n_year
		@info "year: $y"

		ρ = ρ0 + (.02*rand() - .01)
		l = length(authors)

		Ns,authks = get_Ns(authors)

		γ = gamma(Ns)

		for k in 1:length(Ns)
			# Number of papers to be published by the set of authors with k papers
			Tk = round(Int64,k*Ns[k]*γ*ppyear)

			ages = get_ages(authors,authks[k])
			
			if length(ages) > 0
				ids = rand_age(Tk,ages,ρ,amin,amax)
				
				for i in ids
					if i == 0
						authors[length(authors)+1] = Dict{String,Any}("age" => 1, "npaper" => 1)
					else
						authors[authks[k][i]]["npaper"] += 1
					end
				end
			end
		end

		for a in keys(authors)
			authors[a]["age"] += 1
		end
		
	end

	v = [authors[a]["npaper"] for a in keys(authors)]
	
	if length(savefolder) > 0
		params = retrieve_params()
		K = keys(params)
		if length(K) > 0
			id = maximum(K) + 1
		else
			id = 100001
		end
		
		writedlm(savefolder*"/d_$(id).csv",v,',')
		write(savefolder*"/p_$(id).jl","d = Dict{String,Any}(\"id\" => $(id), \"n_year\" => $(n_year), \"ppyear\" => $(ppyear), \"rho0\" => $(ρ0), \"amin\" => $(amin), \"amax\" => $(amax))")
	end

	return v
	
end


"""
	init_authors(ppyear::Int64)

Arbitrary initialization of the list of authors the `generate_distr` function. 

_INPUT_:\\
`ppyear`: Number of papers published every year in the journal.

_OUTPUT_:\\
`authors`: Dictionary whose keys are the authors indices and whose values are themselves dictionaries, with two string keys:\\
	- "age": is the academic age of the authors;\\
	- "npaper": is the current number of papers of this author in the journal.
"""
function init_authors(ppyear::Int64)
	authors = Dict{Int64,Any}()
	p0 = floor(Int64,ppyear/6)
	
	for i in 1:p0
		authors[i] = Dict{String,Int64}()
		authors[i]["age"] = 1
		authors[i]["npaper"] = 1
		authors[i+p0] = Dict{String,Int64}()
		authors[i+p0]["age"] = 1
		authors[i+p0]["npaper"] = 2
		authors[i+2*p0] = Dict{String,Int64}()
		authors[i+2*p0]["age"] = 1
		authors[i+2*p0]["npaper"] = 3
	end

	return authors
end


"""
	get_Ns(authors::Dict{Int64,Any})

Returns, for each possible number of papers `k`, the number of authors with `k` papers.

_INPUT_:\\
`authors`: Dictionary whose keys are the authors indices and whose values are themselves dictionaries, with two string keys:\\
	- "age": is the academic age of the authors;\\
	- "npaper": is the current number of papers of this author in the journal.

_OUTPUT_:\\
`Ns`: Vector of `Int64`, whose k-th component is the number of authors with k papers.\\
`authks`: Vector of `Vector{Int64}` whose k-th component is the list of authors (indices) with k papers.
"""
function get_Ns(authors::Dict{Int64,Any})
	l = maximum([authors[i]["npaper"] for i in keys(authors)])

	Ns = zeros(Int64,l)
	authks = [Array{Int64,1}() for i in 1:l]

	for a in keys(authors)
		np = authors[a]["npaper"]
		Ns[np] += 1
		push!(authks[np],a)
	end

	return Ns,authks
end

"""
	get_ages(authors::Dict{Int64,Any}, authk::Vector{Int64})

Returns the vector of ages of the authors listed in authk.

_INPUT_:\\
`authors`: Dictionary whose keys are the authors indices and whose values are themselves dictionaries, with two string keys:\\
	- "age": is the academic age of the authors;\\
	- "npaper": is the current number of papers of this author in the journal.\\
`authk`: List of authors indices. Typically a component of the output `authks` of the function `get_Ns`.

_OUTPUT_:\\
`ages`: Vector of the ages of the authors in `authk`.
"""
function get_ages(authors::Dict{Int64,Any}, authk::Array{Int64,1})
	return [authors[authk[i]]["age"] for i in 1:length(authk)]
end


"""
	gamma(Ns::Vector{Int64})

Returns the normalization factor such that sum_k gamma*k*Tk = 1 in the function `generate_distr`.

_INPUT_:\\
`Ns`: Vector of `Int64`, whose k-th component is the number of authors with k papers. Typically the output of `get_Ns`.

_OUTPUT_:\\
`γ`: Normalization factor.
"""
function gamma(Ns::Vector{Int64})
	return 1 ./ sum([k*Ns[k] for k in 1:length(Ns)])
end

"""
	share(a::Int64, amin::Int64=40, amax::Int64=60)
	share(a::Vector{Int64}, amin::Int64=40, amax::Int64=60)

Returns the number of years remaining before retirement at `amax`. Maximum is `amax - amin`.

_INPUT_:\\
`a`: Actual age of the author (or a list of ages).\\
`amin`: Age at which production start reducing.\\
`amax`: Age at which production vanishes.

_OUTPUT_:\\
`diff`: Minimum between the number of years remaining before retirement and the difference `amax - amin`.
"""
function share(a::Int64, amin::Int64=40, amax::Int64=60)
	return max(min(amax-a,amax-amin),0)
end

function share(a::Vector{Int64}, amin::Int64=40, amax::Int64=60)
	return [share(a[i],amin,amax) for i in 1:length(a)]
end


"""
	rand_age(p::Int64, ages::Vector{Int64}, ρ::Float64, amin::Int64=40, amax::Int64=60)

Attributes `p` new papers to a group of authors, taking into account their ages.

_INPUT_:\\
`p`: Number of papers to be attributed.\\
`ages`: Vector of ages of the authors to which the papers will be attributed.\\
`ρ`: Proportion of new authors.\\
`amin`: Age at which production start reducing.\\
`amax`: Age at which production vanishes.

_OUTPUT_:\\
`ids`: List of indices of the authors who got a new article.
"""
function rand_age(p::Int64, ages::Vector{Int64}, ρ::Float64, amin::Int64=40, amax::Int64=60)
	sh = share(ages,amin,amax)
	ids = Vector{Int64}()
	for i in 1:length(ages)
		ids = [ids;i*ones(Int64,sh[i])]
	end

	n_new = floor(Int64,ρ*length(ids))+1
	ids = [zeros(Int64,n_new);ids]

	x = rand(p)
	ix = ceil.(Int64,x*length(ids))

	return ids[ix]
end


"""
	retrieve_params(savefolder::String)

Returns the list of parameters of the synthetic data in the folder `savefolder`, under the form of a dictionary, with keys being the simulation id's. 

_INPUT_:\\
`savefolder`: Name of the folder where the data are saved.

_OUTPUT_:\\
`params`: Dictionary whose keys are the simulations id's and the values are the lists of parameters of the simulations. 
"""
function retrieve_params()
	L = readdir("synth_data")

	ids = Array{Int64,1}()

	for l in L
		if l[1] == 'd'
			push!(ids,parse(Int64,l[3:8]))
		end
	end

	params = Dict{Int64,Dict{String,Any}}()
	for id in ids
		include("synth_data/p_$(id).jl")
		params[id] = d
	end

	return params
end

