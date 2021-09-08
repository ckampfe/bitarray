# see the end of the file for the actual benchmarks

defmodule Helpers do
  def next_greatest_multiple_of_8(n) do
    Bitwise.band(n + 7, -8)
  end

  def mixed_binary(n) do
    Enum.reduce(1..n, 0, fn i, acc ->
      if :erlang.rem(i, 2) == 0 do
        Bitwise.bor(acc, Bitwise.bsl(1, i))
      else
        acc
      end
    end)
    |> :binary.encode_unsigned()
  end
end

defmodule Listfield do
  defstruct [:repr, :number_of_pieces]

  def new(number_of_pieces) do
    %__MODULE__{
      repr:
        Enum.reduce(1..number_of_pieces, [], fn _i, acc ->
          [false | acc]
        end),
      number_of_pieces: number_of_pieces
    }
  end

  def get(%__MODULE__{repr: repr}, index) do
    Enum.at(repr, index)
  end

  def set(%__MODULE__{repr: repr} = this, index) do
    %{this | repr: List.replace_at(repr, index, true)}
  end

  def unset(%__MODULE__{repr: repr} = this, index) do
    %{this | repr: List.replace_at(repr, index, false)}
  end

  if Code.ensure_loaded?(:erts_debug) &&
       Code.ensure_loaded?(:erlang) &&
       Kernel.function_exported?(:erts_debug, :size, 1) &&
       Kernel.function_exported?(:erlang, :system_info, 1) do
    @doc """
    The total size in bytes of the BitArray structure
    """
    def size_bytes(%__MODULE__{} = this) do
      :erts_debug.size(this) * :erlang.system_info(:wordsize)
    end
  end
end

defmodule Arrayfield do
  defstruct [:repr, :number_of_pieces]

  def new(number_of_pieces) do
    %__MODULE__{
      repr: :array.new(number_of_pieces, default: false),
      number_of_pieces: number_of_pieces
    }
  end

  def get(%__MODULE__{repr: repr}, index) do
    :array.get(index, repr)
  end

  def set(%__MODULE__{repr: repr} = this, index) do
    %{this | repr: :array.set(index, true, repr)}
  end

  def unset(%__MODULE__{repr: repr} = this, index) do
    %{this | repr: :array.set(index, false, repr)}
  end

  if Code.ensure_loaded?(:erts_debug) &&
       Code.ensure_loaded?(:erlang) &&
       Kernel.function_exported?(:erts_debug, :size, 1) &&
       Kernel.function_exported?(:erlang, :system_info, 1) do
    @doc """
    The total size in bytes of the BitArray structure
    """
    def size_bytes(%__MODULE__{} = this) do
      :erts_debug.size(this) * :erlang.system_info(:wordsize)
    end
  end
end

Benchee.run(
  %{
    # "to_binary/1" => fn input -> BitArray.to_binary(input) end,
    # "to_list/1" => fn input -> BitArray.to_list(input) end,
    # "all?/1" => fn input -> BitArray.all?(input) end,
    # "none?/1" => fn input -> BitArray.all?(input) end,
    # "set_count/1" => fn input -> BitArray.set_count(input) end,
    # "unset_count/1" => fn input -> BitArray.unset_count(input) end,
    # "any_set?/1" => fn input -> BitArray.any_set?(input) end,
    # "any_unset?/1" => fn input -> BitArray.any_unset?(input) end,
    "BitArray.get/2" => {
      fn {input, index} -> BitArray.get(input, index) end,
      before_scenario: fn input ->
        {BitArray.from_binary(
           Helpers.mixed_binary(input),
           Helpers.next_greatest_multiple_of_8(input)
         ), (9 / 10 * input) |> Kernel.ceil()}
      end
    },
    "BitArray.set/2" => {
      fn {input, index} -> BitArray.set(input, index) end,
      before_scenario: fn input ->
        {BitArray.from_binary(
           Helpers.mixed_binary(input),
           Helpers.next_greatest_multiple_of_8(input)
         ), (9 / 10 * input) |> Kernel.ceil()}
      end
    },
    "BitArray.unset/2" => {
      fn {input, index} -> BitArray.unset(input, index) end,
      before_scenario: fn input ->
        {BitArray.from_binary(
           Helpers.mixed_binary(input),
           Helpers.next_greatest_multiple_of_8(input)
         ), (9 / 10 * input) |> Kernel.ceil()}
      end
    },
    "Listfield.get/2" => {
      fn {input, index} -> Listfield.get(input, index) end,
      before_scenario: fn input ->
        {Listfield.new(input), (9 / 10 * input) |> Kernel.ceil()}
      end
    },
    "Listfield.set/2" => {
      fn {input, index} -> Listfield.set(input, index) end,
      before_scenario: fn input ->
        {Listfield.new(input), (9 / 10 * input) |> Kernel.ceil()}
      end
    },
    "Listfield.unset/2" => {
      fn {input, index} -> Listfield.unset(input, index) end,
      before_scenario: fn input ->
        {Listfield.new(input), (9 / 10 * input) |> Kernel.ceil()}
      end
    },
    "Arrayfield.get/2" => {
      fn {input, index} -> Arrayfield.get(input, index) end,
      before_scenario: fn input ->
        {Arrayfield.new(input), (9 / 10 * input) |> Kernel.ceil()}
      end
    },
    "Arrayfield.set/2" => {
      fn {input, index} -> Arrayfield.set(input, index) end,
      before_scenario: fn input ->
        {Arrayfield.new(input), (9 / 10 * input) |> Kernel.ceil()}
      end
    },
    "Arrayfield.unset/2" => {
      fn {input, index} -> Arrayfield.unset(input, index) end,
      before_scenario: fn input ->
        {Arrayfield.new(input), (9 / 10 * input) |> Kernel.ceil()}
      end
    }
  },
  inputs: %{
    "small" => 100,
    "medium" => 1_000,
    "large" => 10_000,
    "very large" => 100_000
  }
)
