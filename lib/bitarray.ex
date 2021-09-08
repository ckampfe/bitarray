defmodule BitArray do
  defstruct [:repr, :number_of_pieces, :bitspace]

  @typep repr :: integer()
  @typep bitspace :: pos_integer()
  @type number_of_pieces :: pos_integer()
  @type index :: non_neg_integer()
  @opaque t :: %__MODULE__{
            repr: repr,
            number_of_pieces: number_of_pieces,
            bitspace: bitspace
          }

  @spec new(pos_integer()) :: %__MODULE__{
          repr: 0,
          number_of_pieces: pos_integer(),
          bitspace: non_neg_integer()
        }
  def new(number_of_pieces) when is_integer(number_of_pieces) and number_of_pieces >= 1 do
    bitspace = next_greatest_multiple_of_8(number_of_pieces)

    %__MODULE__{
      repr: 0,
      number_of_pieces: number_of_pieces,
      bitspace: bitspace
    }
  end

  @spec from_binary(binary(), number_of_pieces()) :: t
  def from_binary(binary, number_of_pieces)
      when is_binary(binary) and
             is_integer(number_of_pieces) and
             number_of_pieces >= 1 and
             number_of_pieces <= byte_size(binary) * 8 do
    integer = binary_to_integer(binary)
    bitspace = next_greatest_multiple_of_8(number_of_pieces) |> Kernel.ceil()

    %__MODULE__{
      repr: integer,
      number_of_pieces: number_of_pieces,
      bitspace: bitspace
    }
  end

  @spec to_binary(t) :: binary()
  def to_binary(%__MODULE__{
        repr: integer,
        bitspace: bitspace
      }) do
    binary = integer_to_binary(integer)
    expected_bytes_size = (bitspace / 8) |> Kernel.ceil()
    padding_bytes = expected_bytes_size - byte_size(binary)

    if padding_bytes > 0 do
      Enum.reduce(0..(padding_bytes - 1), binary, fn _, acc ->
        # in the case that we only set bits further into the structure, ie,
        # <<0, 128>> (going from MSB to LSB),
        # we will need to pad the leading bytes, as :binary.encode_unsigned will
        # return, for example, :binary.encode_unsigned(128) == <<128>>,
        # rather than <<0, 128>>, as we need given a bit space with size `>8 && <17`
        <<0>> <> acc
      end)
    else
      binary
    end
  end

  @spec to_list(t()) :: list(boolean())
  def to_list(%__MODULE__{number_of_pieces: number_of_pieces} = this) do
    as_binary = to_binary(this)

    for <<bit::1 <- as_binary>> do
      bit == 1
    end
    |> Enum.take(number_of_pieces)
  end

  @spec get(t(), index()) :: boolean()
  def get(
        %__MODULE__{repr: integer, number_of_pieces: number_of_pieces, bitspace: bitspace},
        index
      )
      when index <= number_of_pieces do
    mask = bitmask_for_index(index, bitspace)
    Bitwise.band(integer, mask) == mask
  end

  @spec set(t(), index()) :: t()
  def set(%__MODULE__{repr: integer, bitspace: bitspace} = this, index) do
    mask = bitmask_for_index(index, bitspace)
    %{this | repr: Bitwise.bor(integer, mask)}
  end

  @spec unset(t(), index()) :: t
  def unset(%__MODULE__{repr: integer, bitspace: bitspace} = this, index) do
    mask = bitmask_for_index(index, bitspace)
    %{this | repr: Bitwise.band(integer, Bitwise.bnot(mask))}
  end

  # naive, linear solution, but it works
  @spec all?(t()) :: boolean()
  def all?(%__MODULE__{repr: integer}) do
    bits = Integer.digits(integer, 2)
    :erlang.rem(Enum.count(bits), 8) == 0 && Enum.all?(bits, fn d -> d == 1 end)
  end

  @spec none?(t()) :: boolean()
  def none?(%__MODULE__{repr: integer}) do
    bits = Integer.digits(integer, 2)
    Enum.all?(bits, fn d -> d == 0 end)
  end

  @spec set_count(t()) :: non_neg_integer()
  def set_count(%__MODULE__{repr: integer}) do
    integer
    |> Integer.digits(2)
    |> Enum.reduce(0, fn bit, acc ->
      if bit == 1 do
        acc + 1
      else
        acc
      end
    end)
  end

  @spec unset_count(t()) :: non_neg_integer()
  def unset_count(%__MODULE__{number_of_pieces: number_of_pieces} = this) do
    set_count = set_count(this)
    number_of_pieces - set_count
  end

  @spec any_set?(t()) :: boolean()
  def any_set?(%__MODULE__{} = this) do
    set_count(this) > 0
  end

  @spec any_unset?(t()) :: boolean()
  def any_unset?(%__MODULE__{} = this) do
    unset_count(this) > 0
  end

  if Code.ensure_loaded?(:erts_debug) &&
       Code.ensure_loaded?(:erlang) &&
       Kernel.function_exported?(:erts_debug, :size, 1) &&
       Kernel.function_exported?(:erlang, :system_info, 1) do
    @doc """
    The total size in bytes of the BitArray structure
    """
    @spec size_bytes(t()) :: non_neg_integer()
    def size_bytes(%__MODULE__{} = this) do
      :erts_debug.size(this) * :erlang.system_info(:wordsize)
    end
  end

  ### PRIVATE

  @compile {:inline, bitmask_for_index: 2}
  defp bitmask_for_index(index, bitspace) do
    shift = bitspace - index - 1
    Bitwise.bsl(1, shift)
  end

  defp binary_to_integer(binary) do
    :binary.decode_unsigned(binary, :big)
  end

  defp integer_to_binary(integer) do
    :binary.encode_unsigned(integer, :big)
  end

  defp next_greatest_multiple_of_8(n) do
    Bitwise.band(n + 7, -8)
  end
end
