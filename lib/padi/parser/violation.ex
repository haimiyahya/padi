defmodule Padi.Parser.Violation do
  @moduledoc """
  Policy violation result struct.
  """

  @type t :: %__MODULE__{
    rule_id: String.t(),
    rule_name: String.t(),
    action: String.t(),
    reason: String.t(),
    recommendation: String.t(),
    failing_node: map() | nil,
    location: map() | nil
  }

  defstruct [
    :rule_id,
    :rule_name,
    :action,
    :reason,
    :recommendation,
    :failing_node,
    :location
  ]

  @doc """
  Create a new violation.
  """
  def new(rule_id, rule_name, action, reason, recommendation) do
    %__MODULE__{
      rule_id: rule_id,
      rule_name: rule_name,
      action: action,
      reason: reason,
      recommendation: recommendation,
      failing_node: nil,
      location: nil
    }
  end

  @doc """
  Add the failing AST node to the violation.
  """
  def with_failing_node(%__MODULE__{} = violation, node) do
    %{violation | failing_node: node}
  end

  @doc """
  Add the location to the violation.
  """
  def with_location(%__MODULE__{} = violation, location) do
    %{violation | location: location}
  end
end
