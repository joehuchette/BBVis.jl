module BBVis

using JuMP, MathProgBase, CPLEX, Gurobi, Gadfly

export NodeData, record_node_data, plot_mip_gap, plot_mip_gaps

const sampling_rate = 100

immutable NodeData
    node::Int
    incumbent_value::Float64
    bestbound::Float64
end

function record_node_data(model::JuMP.Model)
    model.ext[:bbvis] = NodeData[]
    solvehook = get_node_callback_setter(model, model.solver)
    JuMP.setSolveHook(model, solvehook)
end

function get_node_callback_setter(model::JuMP.Model, solver::CPLEX.CplexSolver)
    node_data = model.ext[:bbvis]
    function node_data_callback(cb)
        nodes_explored  = MathProgBase.cbgetexplorednodes(cb)
        nodes_explored % sampling_rate == 0 || return
        has_incumbent   = CPLEX.cbgetfeasibility(cb)
        incumbent_value = MathProgBase.cbgetobj(cb)
        bestbound       = MathProgBase.cbgetbestbound(cb)
        push!(node_data, NodeData(nodes_explored,
                                  has_incumbent == 1 ? incumbent_value : NaN,
                                  bestbound))
        nothing
    end

    return function solvehook(model::JuMP.Model; args...)
        JuMP.buildInternalModel(model)
        model.internalModel.infocb = node_data_callback
        CPLEX.setmathproginfocallback!(model.internalModel)
        JuMP.solve(model; ignore_solve_hook=true, args...)
    end
end

function plot_mip_gap(model::JuMP.Model)
    nodes = model.ext[:bbvis]
    Gadfly.plot(layer(x=[n.node for n in nodes], y=[n.incumbent_value for n in nodes], Geom.line),
                layer(x=[n.node for n in nodes], y=[n.bestbound       for n in nodes], Geom.line),
                Guide.xlabel("Node number"), Guide.ylabel(""), Stat.step)
end

function plot_mip_gaps(models::JuMP.Model...)
    layers = []
    for (it,model) in enumerate(models)
        nodes = model.ext[:bbvis]
        append!(layers, [layer(x=[n.node for n in nodes], y=[n.incumbent_value for n in nodes], color=["Model $it"], Stat.step, Geom.line),
                         layer(x=[n.node for n in nodes], y=[n.bestbound       for n in nodes], color=["Model $it"], Stat.step, Geom.line)])
    end
    return plot(layers..., Guide.xlabel("Node number"), Guide.ylabel(""), Stat.step)
end

end
