defmodule OpenBLASBuilder do
  @moduledoc """
  Documentation for `OpenBLASBuilder`.
  """

  @doc """
  Downloads the file at `url` to the path of `dest`.
  """
  def download(url, dest) do
     command =
      case network_tool() do
        :curl -> "curl --fail -L #{url} -o #{dest}"
        :wget -> "wget -O #{dest} #{url}"
      end

      case System.shell(command) do
        {_, 0} -> :ok
        _ -> :error
      end
  end

  @doc """
  Gets the text from `url`.
  """
  def get(url) do
    command =
      case network_tool() do
        :curl -> "curl --fail --silent -L #{url}"
        :wget -> "wget -q -O - #{url}"
      end

      case System.shell(command) do
        {body, 0} -> {:ok, body}
        _ -> :error
      end
  end

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
