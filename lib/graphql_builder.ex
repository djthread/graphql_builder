defmodule GraphqlBuilder do
  @moduledoc """
  Module conatining business logic for buiilding GraphQL queries and mutations.
  """

  alias GraphqlBuilder.Query

  def query(query) do
    build(query_keyword(), query)
  end

  def mutation(query) do
    build(mutation_keyword(), query)
  end

  def subscription(query) do
    build(subscription_keyword(), query)
  end

  def build(type_keyword, %Query{operation: operation, fields: fields, variables: variables}) do
    indent_level = 2

    [
      type_keyword,
      operation_and_variables(operation, variables),
      query_fields(fields, indent_level + 2, newline: true),
      indented_closing_brace(indent_level),
      indented_closing_brace(indent_level - 2)
    ]
    |> Enum.join()
  end

  defp query_keyword do
    "query {\n"
  end

  defp mutation_keyword do
    "mutation {\n"
  end

  defp subscription_keyword do
    "subscription {\n"
  end

  defp operation_and_variables(operation, variables, opts \\ []) do
    indent_level = Keyword.get(opts, :indent_level, 2)

    indent(indent_level) <>
      "#{operation}" <>
      variable_list(variables) <>
      " {\n"
  end

  defp indented_closing_brace(indent_level) do
    indent(indent_level) <> "}\n"
  end

  defp query_fields(fields, indent_level, opts \\ []) do
    eol =
      if Keyword.get(opts, :newline, false) do
        "\n"
      else
        ""
      end

    if Enum.all?(fields, &is_atom/1) do
      fields
      |> Enum.map(&(indent(indent_level) <> "#{&1}"))
      |> Enum.join(",\n")
    else
      {field_string, _} = Enum.reduce(fields, {"", indent_level}, &process_nested_field/2)
      field_string
    end <>
      eol
  end

  defp process_nested_field(elem, {acc, indent_level}) when is_atom(elem) do
    {acc <> indent(indent_level) <> "#{elem},\n", indent_level}
  end

  defp process_nested_field({label, sub_fields}, {acc, indent_level}) do
    acc =
      acc <>
        indent(indent_level) <>
        "#{label} {\n" <>
        query_fields(sub_fields, indent_level + 2) <>
        "\n" <> indent(indent_level) <> "}"

    {acc, indent_level}
  end

  defp variable_list(nil) do
    ""
  end

  defp variable_list(variables) do
    variables
    |> Enum.map(&variable/1)
    |> Enum.join(", ")
    |> (fn list -> "(#{list})" end).()
  end

  defp variable({key, value}) do
    cond do
      is_binary(value) ->
        "#{key}: \"#{value}\""

      Keyword.keyword?(value) ->
        list = sub_variable_list(value)
        "#{key}: #{list}"

      is_list(value) ->
        joined_values = Enum.map_join(value, ",", &quote_if_binary/1)
        "#{key}: [#{joined_values}]"

      true ->
        "#{key}: #{value}"
    end
  end

  defp quote_if_binary(string) when is_binary(string), do: "\"#{string}\""
  defp quote_if_binary(not_string), do: not_string

  defp sub_variable_list(variables) do
    variables
    |> Enum.map(&variable/1)
    |> Enum.join(", ")
    |> (fn list -> "{#{list}}" end).()
  end

  defp indent(n) do
    String.duplicate(" ", n)
  end
end
