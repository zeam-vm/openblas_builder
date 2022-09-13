defmodule OpenBLASBuilder do
  @moduledoc """
  Documentation for `OpenBLASBuilder`.
  """

  @github_repo "xianyi/OpenBLAS"
  @version "0.3.21"

  @doc """
  Returns release_tag.
  """
  def release_tag() do
    "v#{@version}"
  end

  @doc """
  Lists release files.
  """
  def list_release_files() do
    url = "https://api.github.com/repos/#{@github_repo}/releases/tags/#{release_tag()}"

    with {:ok, body} <- get(url) do
      # We don't have a JSON library available here, so we do
      # a simple matching
      {:ok, Regex.scan(~r/"name":\s+"(.*\.tar\.gz)"/, body) |> Enum.map(&Enum.at(&1, 1))}
    end
  end

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
