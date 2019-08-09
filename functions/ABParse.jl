using Pkg
cd("c:/Users/francis.smart.ctr/GitDir/AbstractLogicJL")
Pkg.activate(".")

# Global set variables Ω, Υ hold
integer(x::AbstractString) = parse(Int, strip(x))
Base.range(x::AbstractString) = range(integer(match(r"^[0-9]+", x).match),
                               stop = integer(match(r"[0-9]+$", x).match))
ABoccursin(y::Symbol) = any( [ y ∈ keys(Ω[i]) for i in 1:length(Ω) ] )
ABoccursin(x::Hotcomb, y::Symbol) = y ∈ keys(x)

#command = "a,b,c,d ∈ 1:5"

function ABparse(commands::Array{String,1}; Ω::Hotcomb = Hotcomb(0), ℧::AbstractArray{Bool,1} = Bool[0])
  println("")

  for command in commands
      print(command)
      Ω, ℧ = ABparse(command, Ω, ℧)

      feasibleoutcomes = (length(℧)>0) ? sum(℧) : 0
      filler = repeat("\t", max(1, 3-Integer(round(length(command)/18))))

      (feasibleoutcomes == 0)  && (check = "X")
      (feasibleoutcomes > 1)   && (check = "✓")
      (feasibleoutcomes == 1)  && (check = "✓✓")

      println(" $filler feasible outcomes $feasibleoutcomes $check")

  end
  (Ω, ℧)
end

function ABparse(command::String,  Ω::Hotcomb, ℧::AbstractArray{Bool,1})
  # A vector of non-standard operators to ignore
  exclusionlist = ["\bin\b"]

  if occursin(r"∈|\bin\b", command)
      (Ω,℧) = ABassign(command)
      return (Ω,℧)
  end

  # Check for the existance of any symbols in Ω
  varcheck = eachmatch(r"[a-zA-Z][0-9a-zA-Z_.]*", command)

  # Checks if any of the variables does not exist in Ω
  for S in [Symbol(s.match) for s in varcheck if !(s.match ∈ exclusionlist)]
      if (occursin("{{", string(S))) && (!ABoccursin(Ω, S))
          throw("In {$command} variable {:$S} not found in Ω")
      end
  end

  if occursin(r"( |\b)([><=|!+\\-]{4})(\b| )", command)
      (Ω,℧) = SuperSuperOperatorEval(command,Ω,℧)
      return (Ω,℧)
  elseif occursin(r"( |\b)([><=|!+\\-]{3})(\b| )", command)
      (Ω,℧) = SuperOperatorEval(command,Ω,℧)
      return (Ω,℧)
  elseif occursin(r"( |\b)([><=|!]{1,2})(\b| )", command)
      (Ω,℧) = OperatorEval(command,Ω,℧)
      return (Ω,℧)
  end
  println("Warning! { $command } not interpretted")
end

function ABassign(command::String)
  vars, valsin = strip.(split(command, r"∈|\bin\b"))
  varsVect = split(vars, ",") .|> strip
  vals0 = split(replace(valsin, r"\[|\]" => ""), ",")

  (length(vals0) > 1) && (vals =  [(occursin(r"^[0-9]+$", i) && integer(i)) for i in vals0])
  (length(vals0) == 1 && occursin(r"^[0-9]+:[0-9]+$", vals0[1])) && (vals = range(vals0[1]))

  outset = (; zip([Symbol(i) for i in varsVect], fill(vals, length(vars)))...)

  Ω  = Hotcomb(outset)
  ℧ = fill(true, size(Ω)[1])

  (Ω ,℧)
end

function grab(argument::AbstractString, Ω::Hotcomb, ℧::AbstractArray{Bool,1}; command = "")
  matcher = r"^([a-zA-z][a-zA-z0-9]*)*([0-9]+)*([+\-*/])*([a-zA-z][a-zA-z0-9]*)*([0-9]+)*$"

  m = match(matcher, argument)
  nvar = 5-sum([i === nothing for i in m.captures])
  (nvar==0) && throw("Argument $argument could not be parsed in $command")

  v1, n1, o1, v2, n2 = m.captures

  !(v1 === nothing) && (left  = Ω[℧, Symbol(v1)])
  !(n1 === nothing) && (left  = fill(integer(n1), length(℧)))

  (nvar==1) && return left

  !(v2 === nothing) && (right = Ω[℧, Symbol(v2)])
  !(n2 === nothing) && (right = fill(integer(n2), length(left)))

  (o1 == "+") && return left .+ right
  (o1 == "-") && return left .- right
  (o1 == "/") && return left ./ right
  (o1 == "*") && return left .* right
end

#commands = ["a, b, c  ∈  [1,2,3]", "b = a|c {2}"]
#command = commands[1]
#command = commands[2]

function SuperSuperOperatorEval(command, Ω::Hotcomb, ℧::AbstractArray{Bool,1})
    #println("OperatorEval($command)")
    (sum(℧) == 0) && return (Ω, ℧)

    m = match(r"(.*)(\b([><=|!+\\-]{4})\b)(.*)",replace(command, " "=>""))
    left, blank, supersuperoperator, right = m.captures

    υ = copy(℧); ℧η = copy(℧)

    ℧left  = SuperOperatorEval(left ,Ω,℧)[2]
    ℧right = SuperOperatorEval(right,Ω,℧)[2]

    (supersuperoperator == "====") && (℧η = υ .& (℧left .& ℧right))

    (Ω, ℧η)
end


function SuperOperatorEval(command, Ω::Hotcomb, ℧::AbstractArray{Bool,1})
    #println("OperatorEval($command)")
    (sum(℧) == 0) && return (Ω, ℧)
    (!occursin(r"( |\b)([><=|!+\\-]{3})(\b| )", command)) && return OperatorEval(command, Ω, ℧)
    occursin(r"\{\{.*\}\}", command) && return OperatorSpawn(command, Ω, ℧)


    m = match(r"(.*)(\b([><=|!+\\-]{3})\b)(.*)",replace(command, " "=>""))
    left, blank, superoperator, right = m.captures

    υ = copy(℧); ℧η = copy(℧)

    ℧left  = OperatorEval(left ,Ω,℧)[2]
    ℧right = OperatorEval(right,Ω,℧)[2]

    if superoperator == "==="
        ℧η = υ .& (℧left .& ℧right)

    elseif superoperator == "^^^"
        ℧η = υ .& ((℧left .& .!℧right) .| (.!℧left .& ℧right))

    elseif superoperator == "---"
        ℧η[υ] = (℧left .- ℧right)[υ]

    elseif superoperator == "+++"
        ℧η = ℧left .+ ℧right

    elseif superoperator == "|||"
        ℧η = υ .& (℧left .| ℧right)

    elseif superoperator ∈ ["|=>","==>"]
        ℧η[℧left] .= ℧[℧left]  .& ℧right[℧left]

    elseif superoperator ∈ ["<=|","<=="]
        ℧η[℧right] = ℧[℧right] .& ℧left[℧right]

    elseif superoperator ∈ ["<=>","<=>"] # ???????????????????????????????????
        ℧η[℧right]     .=  ℧[℧right]   .&   ℧left[℧right]
        ℧η[.!℧right]   .=  ℧[.!℧right] .& .!℧left[.!℧right]
    end
    (Ω, ℧η)
end


#command = "b |= a,c {4}"
#command = "b |= a,c {2}"
#command = "(!i) == (!i) (2)"
#command = "{{i}} == {{!i}} {{2,3}}"
#command = "{{i}} == {{!i}} {{2}}"

command = "{{i}} > {{i+1}}"

function OperatorSpawn(command, Ω::Hotcomb, ℧::AbstractArray{Bool,1})
    tempcommand = command
    m = eachmatch(r"(\{\{.*?\}\})", tempcommand)
    matches = [replace(x[1], r"\{|\}"=>"") for x in collect(m)] |> unique

    if occursin(r"^[0-9]+,[0-9]+$", matches[end])
        countrange = (x -> x[1]:x[2])(integer.(split(matches[end], ",")))
        tempcommand = replace(tempcommand, "{{$(matches[end])}}"=>"") |> strip
        matches = matches[1:(end-1)]
    elseif occursin(r"^[0-9]+$", matches[end])
        countrange = (x -> x[1]:x[1])(integer(matches[end]))
        tempcommand = replace(tempcommand, "{{$(matches[end])}}"=>"") |> strip
        matches = matches[1:(end-1)]
    else
        countrange = missing
    end

    mykeys = keys(Ω)
    ("!i" ∈ matches) && (keyrange = collect(1:length(mykeys)))
    !("!i" ∈ matches) && (keyrange = 0)

    positivematches = matches[matches .!= "!i"]

    collection = []

    for i in 1:length(mykeys), j in keyrange[keyrange .!= i]
       txtcmd = tempcommand

       ("!i" ∈ matches) && (txtcmd = subout(txtcmd, j, "!i", mykeys))
       for m in positivematches; txtcmd = subout(txtcmd, i, m, mykeys); end

       occursin("~~OUTOFBOUNDS~~", txtcmd) && continue

       ℧∇ = SuperOperatorEval(txtcmd, Ω, ℧)[2]

       print("\n>>> $txtcmd")

       push!(collection, ℧∇)
    end


    collector = hcat(collection...)

    if (countrange === missing)
      ℧Δ = ℧ .& [all(collector[i,:]) for i in 1:size(collector)[1]]
    else
      ℧Δ = ℧ .& [sum(collector[i,:]) ∈ countrange for i in 1:size(collector)[1]]
    end
    (Ω, ℧Δ)
end

#Ω[℧Δ]

function subout(txtcmd, i, arg, mykeys)
  lookup(vect, i) = i ∈ 1:length(vect) ? vect[i] : "~~OUTOFBOUNDS~~"

  (arg ∈ ["i", "!i"])  && return replace(txtcmd, "{{$arg}}"=>lookup(mykeys,i))

  mod = integer(match(r"([0-9]+$)", arg).match)

  occursin("+", arg) && return replace(txtcmd, "{{$arg}}"=>lookup(mykeys,i+mod))
  occursin("-", arg) && return replace(txtcmd, "{{$arg}}"=>lookup(mykeys,i+mod))

  txtcmd
end

#command = "{{i}} == {{i+1}} {{2}}"
#txtcmd = subout(txtcmd, 1, "i+1", mykeys)
#txtcmd = subout(txtcmd, 1, "i", mykeys)

function OperatorEval(command, Ω::Hotcomb, ℧::AbstractArray{Bool,1})
    #println("OperatorEval($command)")

    (sum(℧) == 0) && return (Ω, ℧)
    occursin(r"\{\{.*\}\}", command) && return OperatorSpawn(command, Ω, ℧)


    n = 1:sum(℧); ℧Δ = copy(℧); ℧η = copy(℧)

    # convert a = b|c to a |= b,c
    if occursin("|", command) &  occursin(r"(\b| )[|]*=+[|]*(\b| )", command)
      command = replace(command, "|"=>",")
      command = replace(command, r",*=+,*"=>"|=")
    end

    m = match(r"^(.*)(\b([><=|!]{1,2})\b)(.*?)(\{([0-9]+),?([0-9]+)*\})?$",replace(command, " "=>""))
    left, right, operator, nmin, nmax  = m.captures[[1,4,3,6,7]]

    (nmin === nothing) && (nmax === nothing)  &&  (nrange = 1:999)
    !(nmin === nothing) && (nmax === nothing) &&  (nrange = integer(nmin):integer(nmin))
    !(nmin === nothing) && !(nmax === nothing) && (nrange = integer(nmin):integer(nmax))

    leftarg  = strip.(split(left,  r"[,&]"))
    rightarg = strip.(split(right, r"[,&]"))

    leftvals  = hcat([grab(L, Ω, ℧, command=command) for L in leftarg]...)
    rightvals = hcat([grab(R, Ω, ℧, command=command) for R in rightarg]...)

    if operator == "!="
        lcheck = [any(leftvals[i,j] .== rightvals[i,:]) for i in n, j in 1:size(leftvals)[2]]
        ℧Δ = [!all(lcheck[i,:]) for i in n]

    elseif operator  ∈ ["==","="]
        lcheck = [all(leftvals[i,j] .== rightvals[i,:]) for i in n, j in 1:size(leftvals)[2]]
        ℧Δ = [all(lcheck[i,:]) for i in n]

    elseif operator ∈ ["|=", "=|"]
        lcheck = [any(leftvals[i,j] .== rightvals[i,:]) for i in n, j in 1:size(leftvals)[2]]
        ℧Δ = [sum(lcheck[i,:]) ∈ nrange for i in n]

    elseif operator == "<="
        lcheck = [all(leftvals[i,j] .<= rightvals[i,:]) for i in n, j in 1:size(leftvals)[2]]
        ℧Δ = [all(lcheck[i,:]) for i in n]

    elseif operator ∈ ["<<","<"]
        lcheck = [all(leftvals[i,j] .< rightvals[i,:]) for i in n, j in 1:size(leftvals)[2]]
        ℧Δ = [all(lcheck[i,:]) for i in n]

    elseif operator == ">="
        lcheck = [all(leftvals[i,j] .>= rightvals[i,:]) for i in n, j in 1:size(leftvals)[2]]
        ℧Δ = [all(lcheck[i,:]) for i in n]

    elseif operator ∈ [">>",">"]
        lcheck = [all(leftvals[i,j] .> rightvals[i,:]) for i in n, j in 1:size(leftvals)[2]]
        ℧Δ = [all(lcheck[i,:]) for i in n]

    end

    ℧η[℧η] = ℧Δ

    (Ω, ℧η)
end

Ω,℧ = ABparse(["a, b, c  ∈  [1,2,3]", "b != a,c", "c =| 1,2"]); Ω[℧]

Ω,℧ = ABparse(["a, b  ∈  [1,2,3]", "a|b = 1"]);

Ω,℧ = ABparse(["a, b, c  ∈  [1,2,3]", "{{i}} == {{!i}}"]); Ω[℧]
Ω,℧ = ABparse(["a, b, c, d  ∈  [1,2,3,4]", "{{i}} != {{!i}} {{0}}"]); Ω[℧]

Ω,℧ = ABparse(["a, b, c, d  ∈  [1,2,3,4]", "{{i}} != {{!i}} {{3}}"]); Ω[℧] # ??????????????????????
Ω,℧ = ABparse(["a, b, c, d  ∈  [1,2,3,4]", "{{i}} != {{!i}} {{1,5}}"]); Ω[℧]

Ω,℧ = ABparse(["a, b, c  ∈  [1,2,3,4]", "{{i}} > {{i+1}}"]); Ω[℧]

Ω,℧ = ABparse(["a, b  ∈  [1,2,3]", "a|b = 1 {1}"]); Ω[℧,:]
Ω,℧ = ABparse(["a, b  ∈  [1,2,3]", "a|b = 1 {0}"]); Ω[℧,:]

Ω,℧ = ABparse(["a, b, c  ∈  [1,2,3]", "b != a,c", "c =| 1,2 {1}"]); Ω[℧,:]

Ω,℧ = ABparse(["a, b, c  ∈  [1,2,3]", "b != a,c", "c == 1|2"]); Ω[℧,:]
Ω,℧ = ABparse(["a, b, c  ∈  [1,2,3]", "a < b,c",  "c |= 1,2"]);Ω[℧,:]
Ω,℧ = ABparse(["a, b, c  ∈  [1,2,3]", "b < 3 |=> a = b"]); Ω[℧,:]
Ω,℧ = ABparse(["a, b, c  ∈  [1,2,3]", "a == b <=| b << 3"]); Ω[℧,:]
Ω,℧ = ABparse(["a, b, c  ∈  [1,2,3]", "a == 1 <=> b == c"]); Ω[℧,:]
Ω,℧ = ABparse(["a, b, c  ∈  [1,2,3]", "a <= b,c", "c |= 1,2"]); Ω[℧,:]

Ω,℧ = ABparse(["a, b, c     ∈  [1,2,3]", "b , a == c-1", "c |= 1,2"]); Ω[℧,:]
Ω,℧ = ABparse(["a, b, c     ∈  [1,2,3]", "a == c+b"]); Ω[℧,:]
Ω,℧ = ABparse(["a, b, c, d  ∈  [1,2,3,4]", "a , b |= c, d"]); Ω[℧,:]
Ω,℧ = ABparse(["a, b, c, d  ∈  [1,2,3,4]", "a != b, c, d", "b != c,d", "c != d"]); Ω[℧,:]
Ω,℧ = ABparse(["a, b, c, d  ∈  [1,2,3,4]", "a != b, c, d", "b != c,d", "c != d", "a == c+1", "d == a*2"]); Ω[℧,:]

Ω,℧ = ABparse(["a, b, c  ∈  [1,2,3]", "b != a,c", "c =| 1,2"]); Ω[℧,:]

Ω,℧ = ABparse(["a, b, c, d, e, f, g  ∈  [1,2,3,4]", "a,b,c,d,e,f,g == 1 +++ a,b,c,d,e,f,g == 1 ==== 2"]); Ω[℧,:]

Ω,℧ = ABparse(["a, b, c     ∈  [1,2,3]", "b , a == c-1"]); Ω[℧,:]
