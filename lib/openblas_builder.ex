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
        # The archive should have already been built by this point
        archive_path_for_build()

      url = openblas_archive_url() ->
        path = archive_path_for_external_download(url)
        unless File.exists?(path), do: download_external!(url, path)
        path

      true ->
        path = archive_path_for_matching_download()
        unless File.exists?(path), do: download_matching!(path)
        path
    end
  end

  @doc """
  Gets the environment variable "OPENBLAS_ARCHIVE_URL".
  """
  def openblas_archive_url() do
    System.get_env("OPENBLAS_ARCHIVE_URL")
  end

  @doc """
  Gets the path of the archive for building.
  """
  def archive_path_for_build() do
    filename = archive_filename_with_target()
    cache_path(["build", filename])
  end

  @doc """
  Gets the path of the archive for external downloading.
  """
  def archive_path_for_external_download(url) do
    hash = url |> :erlang.md5() |> Base.encode32(case: :lower, padding: false)
    filename = "openblas-#{hash}.tar.gz"
    cache_path(["external", filename])
  end

  @doc """
  Get the cache directory of OpenBLAS.
  """
  def openblas_cache_dir() do
    if dir = System.get_env("OPENBLAS_CACHE_DIR") do
      Path.expand(dir)
    else
      :filename.basedir(:user_cache, "openblas")
    end
  end

  @doc """
  Gets the path of the cache.
  """
  def cache_path(parts) do
    base_dir = openblas_cache_dir()
    Path.join([base_dir, @version, "cache" | parts])
  end

  @doc """
  Download external.
  """
  def download_external!(url, archive_path) do
    assert_network_tool!()
    Logger.info("Downloading OpenBLAS archive from #{url}")
    download_archive!(url, archive_path)
  end

  @doc """
  Gets the file name of the archive with the target.
  """
  def archive_filename_with_target() do
    "openblas-#{target()}.tar.gz"
  end

  @doc """
  Gets the path for matching download()
  """
  def archive_path_for_matching_download() do
    filename = archive_filename_with_target()
    cache_path(["download", filename])
  end

  @doc """
  Gets target.
  """
  def target() do
    {cpu, os} = cpu_and_os()
    "#{cpu}-#{os}"
  end

  @doc """
  Gets information of CPU and OS.
  """
  def cpu_and_os() do
    :erlang.system_info(:system_architecture)
    |> List.to_string()
    |> String.split("-")
    |> case do
      ["arm" <> _, _vendor, "darwin" <> _ | _] -> {"aarch64", "darwin"}
      [cpu, _vendor, "darwin" <> _ | _] -> {cpu, "darwin"}
      [cpu, _vendor, os | _] -> {cpu, os}
      ["win32"] -> {"x86_64", "windows"}
    end
  end

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
  Get URL of the release file.
  """
  def release_file_url(filename) do
    "https://github.com/#{@github_repo}/releases/download/#(release_tag()}/#{filename}"
  end

  @doc """
  Downloads the archive.
  """
  def download_archive!(url, archive_path) do
    File.mkdir_p!(Path.dirname(archive_path))

    if download(url, archive_path) == :error do
      raise "failed to download the OpenBLAS archive from #{url}"
    end

    Logger.info("Successfully downloaded the OpenBLAS archive")
  end

  @doc """
  Downloads matching.
  """
  def download_matching!(archive_path) do
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
  Asserts existence of the network tool.
  """
  def assert_network_tool!() do
    unless network_tool() do
      raise "expected either curl or wget to be available in your system, but neither was found"
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
