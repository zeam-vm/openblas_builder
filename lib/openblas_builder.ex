defmodule OpenBLASBuilder do
  @moduledoc """
  Documentation for `OpenBLASBuilder`.
  """

  @doc """
  Returns `:curl` or `:wget` if found in the PATH.

  Return `nil` if not found.
  """
  def network_tool() do
    cond do
      executable_exists?("curl") -> :curl
      executable_exists?("wget") -> :wget
      true -> nil
    end
  end

  defp executable_exists?(name), do: System.find_executable(name) != nil
end
