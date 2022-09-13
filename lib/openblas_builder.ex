defmodule OpenBLASBuilder do
  @moduledoc """
  Documentation for `OpenBLASBuilder`.
  """

  require Logger

  @github_repo "xianyi/OpenBLAS"
  @version "0.3.21"

  def archive_path!() do
    cond do
      true ->
        path = archive_path_for_matching_download()
        unless File.exists?(path), do: download_matching!(path)
        path
    end
  end

  @doc false
  def make_env() do
    %{
      "ROOT_DIR" => Path.expand("..", __DIR__),
      "BUILD_ARCHIVE" => archive_path_for_build(),
      "BUILD_ARCHIVE_DIR" => build_archive_dir()
    }
  end

  defp openblas_cache_dir() do
    if dir = System.get_env("OPENBLAS_CACHE_DIR") do
      Path.expand(dir)
    else
      :filename.basedir(:user_cache, "openblas")
    end
  end

  defp cache_path(parts) do
    base_dir = openblas_cache_dir()
    Path.join([base_dir, @version, "cache" | parts])
  end

  @doc false
  def archive_filename_with_version() do
    "OpenBLAS-#{@version}.tar.gz"
  end

  defp archive_path_for_matching_download() do
    filename = archive_filename_with_version()
    cache_path(["download", filename])
  end

  defp archive_path_for_build() do
    filename = archive_filename_with_version()
    cache_path(["build", filename])
  end

  @doc false
  def release_tag() do
    "v#{@version}"
  end

  @doc false
  def build_archive_dir() do
    Path.dirname(archive_path_for_build())
  end

  defp list_release_files() do
    url = "https://api.github.com/repos/#{@github_repo}/releases/tags/#{release_tag()}"

    with {:ok, body} <- get(url) do
      # We don't have a JSON library available here, so we do
      # a simple matching
      {:ok, Regex.scan(~r/"name":\s+"(.*\.tar\.gz)"/, body) |> Enum.map(&Enum.at(&1, 1))}
    end
  end

  defp release_file_url(filename) do
    "https://github.com/#{@github_repo}/releases/download/#{release_tag()}/#{filename}"
  end

  defp download_archive!(url, archive_path) do
    File.mkdir_p!(Path.dirname(archive_path))

    if download(url, archive_path) == :error do
      raise "failed to download the OpenBLAS archive from #{url}"
    end

    Logger.info("Successfully downloaded the OpenBLAS archive")
  end

  defp download_matching!(archive_path) do
    assert_network_tool!()

    expected_filename = Path.basename(archive_path)

    filenames =
      case list_release_files() do
        {:ok, filenames} ->
          filenames

        :error ->
          raise "could not find #{release_tag()} release under https://github.com/#{@github_repo}/releases"
      end

    unless expected_filename in filenames do
      listing = filenames |> Enum.map(&["    * ", &1, "\n"]) |> IO.iodata_to_binary()

      raise "none of the precompiled archives matches your target\n" <>
              "  Expected:\n" <>
              "    * #{expected_filename}\n" <>
              "  Found:\n" <>
              listing <>
              "\nYou can compile OpenBLAS locally by setting an environment variable: OPENBLAS_BUILD=true"
    end

    Logger.info("Found a matching archive (#{expected_filename}), going to download it")
    url = release_file_url(expected_filename)
    download_archive!(url, archive_path)
  end

  defp download(url, dest) do
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

  defp get(url) do
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

  defp assert_network_tool!() do
    unless network_tool() do
      raise "expected either curl or wget to be available in your system, but neither was found"
    end
  end

  defp network_tool() do
    cond do
      executable_exists?("curl") -> :curl
      executable_exists?("wget") -> :wget
      true -> nil
    end
  end

  defp executable_exists?(name), do: System.find_executable(name) != nil
end
