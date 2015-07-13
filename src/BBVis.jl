module BBVis

using JuMP, MathProgBase, CPLEX, Gurobi, Gadfly

export NodeData, BBData, record_node_data,
       plot_mip_gap, plot_mip_gaps, plot_mip_gaps_compat, plot_times_compat, plot_progress

const sampling_rate = 100

immutable NodeData
    node::Int
    time::Float64
    incumbent_value::Float64
    bestbound::Float64
end

type BBData
    nodes::Vector{NodeData}
    name::String
end

function node_data_callback(cb, model::Model)
    node_data::Vector{NodeData} = model.ext[:bbvis].nodes
    nodes_explored  = MathProgBase.cbgetexplorednodes(cb)
    nodes_explored % sampling_rate == 0 || return
    node_time       = CPLEX.cbgetstarttime(cb)
    has_incumbent   = CPLEX.cbgetfeasibility(cb)
    incumbent_value = MathProgBase.cbgetobj(cb)
    bestbound       = MathProgBase.cbgetbestbound(cb)
    push!(node_data, NodeData(nodes_explored,
                              node_time,
                              has_incumbent == 1 ? incumbent_value : NaN,
                              bestbound))
    nothing
end

function record_node_data(model::JuMP.Model, name::String)
    model.ext[:bbvis] = BBData(NodeData[], name)
    addInfoCallback(model, cb -> node_data_callback(cb,model))
end

function plot_mip_gap(model::JuMP.Model)
    nodes = model.ext[:bbvis].nodes
    Gadfly.plot(layer(x=[n.node for n in nodes], y=[n.incumbent_value for n in nodes], Geom.line),
                layer(x=[n.node for n in nodes], y=[n.bestbound       for n in nodes], Geom.line),
                Guide.xlabel("Node number"), Guide.ylabel(""), Stat.step)
end

function plot_mip_gaps(models::JuMP.Model...)
    layers = Any[]
    for (it,model) in enumerate(models)
        nodes = model.ext[:bbvis].nodes
        name  = model.ext[:bbvis].name
        append!(layers, [layer(x=[n.node for n in nodes], y=[n.incumbent_value for n in nodes], color=[name], Stat.step, Geom.line),
                         layer(x=[n.node for n in nodes], y=[n.bestbound       for n in nodes], color=[name], Stat.step, Geom.line)])
    end
    return plot(layers..., Guide.xlabel("Node number"), Guide.ylabel(""), Stat.step)
end

function plot_progress(models::JuMP.Model...)
    node_layers = Any[]
    for (it,model) in enumerate(models)
        nodes = model.ext[:bbvis].nodes
        name  = model.ext[:bbvis].name
        append!(node_layers, [layer(x=[n.node for n in nodes], y=[n.incumbent_value for n in nodes], color=[name], Stat.step, Geom.line),
                              layer(x=[n.node for n in nodes], y=[n.bestbound       for n in nodes], color=[name], Stat.step, Geom.line)])
    end

    time_layers = Any[]
    for (it,model) in enumerate(models)
        nodes = model.ext[:bbvis].nodes
        name  = model.ext[:bbvis].name
        append!(time_layers, [layer(x=[n.time for n in nodes], y=[n.incumbent_value for n in nodes], color=[name], Stat.step, Geom.line),
                              layer(x=[n.time for n in nodes], y=[n.bestbound       for n in nodes], color=[name], Stat.step, Geom.line)])
    end
    return vstack(plot(time_layers..., Guide.xlabel("Time (s)"),    Guide.ylabel(""), Stat.step),
                  plot(node_layers..., Guide.xlabel("Node number"), Guide.ylabel(""), Stat.step))
end

function plot_mip_gaps_compat(models::JuMP.Model...)
    max_nodes = 0
    for model in models
        max_nodes = max(max_nodes, model.ext[:bbvis].nodes[end].node)
    end
    plots = Any[]
    for (it,model) in enumerate(models)
        nodes = model.ext[:bbvis].nodes
        name  = model.ext[:bbvis].name
        # p = plot(layer(x=vcat([n.node for n in nodes],max_nodes), y=vcat([n.incumbent_value for n in nodes], nodes[end].incumbent_value), Stat.step, Geom.line),
        #          layer(x=vcat([n.node for n in nodes],max_nodes), y=vcat([n.bestbound       for n in nodes], nodes[end].bestbound),       Stat.step, Geom.line),
        #          Guide.xlabel("Node number"), Guide.ylabel(name), Stat.step)
        p = plot(layer(x=[n.node for n in nodes], y=[n.incumbent_value for n in nodes], Stat.step, Geom.line),
                 layer(x=[n.node for n in nodes], y=[n.bestbound       for n in nodes], Stat.step, Geom.line),
                 Guide.xlabel("Node number"), Guide.ylabel(name), Stat.step, Scale.x_continuous(maxvalue=max_nodes))
        push!(plots, p)
    end
    vstack(plots...)
end

function plot_times_compat(models::JuMP.Model...)
    max_nodes = 0
    for model in models
        max_nodes = max(max_nodes, model.ext[:bbvis].nodes[end].node)
    end
    plots = Any[]
    for (it,model) in enumerate(models)
        nodes = model.ext[:bbvis].nodes
        name  = model.ext[:bbvis].name
        p = plot(layer(x=[n.time for n in nodes], y=[n.incumbent_value for n in nodes], Stat.step, Geom.line),
                 layer(x=[n.time for n in nodes], y=[n.bestbound       for n in nodes], Stat.step, Geom.line),
                 Guide.xlabel("Node number"), Guide.ylabel(name), Stat.step, Scale.x_continuous(maxvalue=max_nodes))
        push!(plots, p)
    end
    vstack(plots...)
end


end
