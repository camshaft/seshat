defmodule Seshat.Context.Msgpack do
  defstruct [:ttl, :id, :user, {:state, %{}}]
end

defimpl Seshat.Context, for: Seshat.Context.Msgpack do
  alias Seshat.Changeset.{Delete, Update}

  def lookup(context, id, user, nil) do
    %{context | id: id, user: user}
  end
  def lookup(context, id, user, serialized) when is_binary(serialized) do
    [check,
     counts,
     properties,
     flags,
     tags,
     _expiration] = Msgpax.unpack!(serialized)

    ^check = check(id, user)

    state = %{}
    |> deserialize_state(:counts, counts)
    |> deserialize_state(:properties, properties)
    |> deserialize_state(:flags, flags)
    |> deserialize_state(:tags, tags)

    %{context | id: id,
                user: user,
                state: state}
  end

  defp deserialize_state(state, _, nil) do
    state
  end
  defp deserialize_state(state, key, value) do
    Map.put(state, key, value)
  end

  def serialize(%{id: id, user: user, ttl: _ttl, state: state}) do
    # TODO compute expiration
    [check(id, user),
     serialize_state(state, :counts),
     serialize_state(state, :properties),
     serialize_state(state, :flags),
     serialize_state(state, :tags),
     0]
    |> Msgpax.pack!()
    |> :erlang.iolist_to_binary()
  end

  defp serialize_state(state, key) do
    case Map.get(state, key) do
      nil ->
        nil
      map when map_size(map) == 0 ->
        nil
      map ->
        map
    end
  end

  defp check(id, user) do
    <<check :: size(4)-binary(), _ :: binary>> = :crypto.hash(:sha, [id, 0, 0, 0, 0, user])
    check
  end

  def apply_op(context = %{state: state}, type, key, op) do
    kvs = state
    |> Map.get(type, %{})
    |> apply_op_type(type, key, op)
    %{context | state: Map.put(state, type, kvs)}
  end

  defp apply_op_type(acc, :counts, key, %Update{value: value}) do
    Map.update(acc, key, value, &(&1 + value))
  end
  defp apply_op_type(acc, :counts, key, %Delete{}) do
    Map.delete(acc, key)
  end
  defp apply_op_type(kvs, :properties, key, %Update{value: value}) do
    Map.put(kvs, key, value)
  end
  defp apply_op_type(kvs, :properties, key, %Delete{}) do
    Map.delete(kvs, key)
  end
  defp apply_op_type(kvs, :flags, key, %Update{value: true}) do
    Map.put(kvs, key, true)
  end
  defp apply_op_type(kvs, :flags, key, _) do
    Map.delete(kvs, key)
  end
  defp apply_op_type(kvs, :tags, key, %Update{value: value}) do
    Map.update(kvs, key, [value], &:ordsets.add_element(value, &1))
  end
  defp apply_op_type(kvs, :tags, key, %Delete{value: value}) do
    case Map.get(kvs, key) do
      nil ->
        kvs
      tags ->
        case :ordsets.del_element(value, tags) do
          [] ->
            Map.delete(kvs, key)
          tags ->
            Map.put(kvs, key, tags)
        end
    end
  end

  for {method, target} <- [count: :counts, property: :properties, flag: :flags, tag: :tags] do
    def unquote(:"list_#{method}_keys")(%{state: state}) do
      kvs = Map.get(state, unquote(target), %{})
      Map.keys(kvs)
    end
  end

  for {method, target} <- [count: :counts, property: :properties, flag: :flags, tags: :tags] do
    def unquote(:"fetch_#{method}")(%{state: state}, key) do
      kvs = Map.get(state, unquote(target), %{})
      Map.fetch(kvs, key)
    end
  end

  def delete(_) do
    nil
  end
end
