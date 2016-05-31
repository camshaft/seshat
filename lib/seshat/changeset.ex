defmodule Seshat.Changeset do
  defmodule Update do
    defstruct value: nil
  end

  defmodule Delete do
    defstruct value: nil
  end

  defstruct valid?: true,
            errors: [],
            updates: %{}

  def new(opts \\ []) do
    struct!(__MODULE__, opts)
  end

  def apply(%{updates: updates}, acc, fun) do
    Enum.reduce(updates, acc, fn({type, kvs}, acc) ->
      Enum.reduce(kvs, acc, fn({key, ops}, acc) ->
        ops
        |> Enum.reverse()
        |> Enum.reduce(acc, fn(op, acc) ->
          fun.(acc, type, key, op)
        end)
      end)
    end)
  end

  def add_error(changeset = %{errors: errors}, error) when is_list(error) do
    %{changeset | valid?: false, errors: errors ++ error}
  end
  def add_error(changeset = %{errors: errors}, error) do
    %{changeset | valid?: false, errors: errors ++ [error]}
  end

  def size(%{updates: updates}) do
    Enum.reduce(updates, 0, fn({_, target}, acc) ->
      acc + map_size(target)
    end)
  end

  def add_count(changeset, _, value) when value == 0 do
    changeset
  end
  def add_count(changeset, name, value) do
    apply_update(changeset, :counts, name, fn
      ([%Update{value: prev}]) ->
        case (prev + value) do
          0 ->
            []
          value ->
            [%Update{value: value}]
        end
      (_) ->
        [%Update{value: value}]
    end)
  end

  def delete_count(changeset, name) do
    put_update(changeset, :counts, name, %Delete{})
  end

  def put_property(changeset, name, value) do
    put_update(changeset, :properties, name, %Update{value: value})
  end

  def delete_property(changeset, name) do
    put_update(changeset, :properties, name, %Delete{})
  end

  def enable_flag(changeset, name) do
    put_flag(changeset, name, true)
  end

  def disable_flag(changeset, name) do
    put_flag(changeset, name, false)
  end

  def put_flag(changeset, name, value) when is_boolean(value) do
    put_update(changeset, :flags, name, %Update{value: value})
  end

  def put_tag(changeset, _, value) when value in ["", <<0>>] do
    changeset
  end
  def put_tag(changeset, name, value) do
    apply_update(changeset, :tags, name, fn(ops) ->
      ops = :ordsets.del_element(%Delete{value: value}, ops)
      :ordsets.add_element(%Update{value: value}, ops)
    end)
  end

  def delete_tag(changeset, name, value) do
    apply_update(changeset, :tags, name, fn(ops) ->
      ops = :ordsets.del_element(%Update{value: value}, ops)
      :ordsets.add_element(%Delete{value: value}, ops)
    end)
  end

  defp put_update(changeset, target, name, op) when is_binary(name) do
    apply_update(changeset, target, name, fn(_) ->
      [op]
    end)
  end

  defp apply_update(changeset, _, "", _) do
    changeset
  end
  defp apply_update(changeset = %{updates: updates}, target, name, update) do
    name = to_string(name)
    target_updates  = Map.get(updates, target, %{})
    updates = case update.(Map.get(target_updates, name, [])) do
      [] ->
        target_updates = Map.delete(target_updates, name)
        if map_size(target_updates) == 0 do
          Map.delete(updates, target)
        else
          Map.put(updates, target, target_updates)
        end
      name_updates ->
        target_updates = Map.put(target_updates, name, name_updates)
        Map.put(updates, target, target_updates)
    end
    %{changeset | updates: updates}
  end
end
