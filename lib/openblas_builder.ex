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
  def extract_archive!() do
    unless executable_exists?("tar") do
      raise "tar was not found"
    end

    src = src_path()
    File.mkdir_p!(src)
    archive = archive_path!()
    command = "tar xfz #{archive}"

    case System.shell(command, cd: src) do
      {_result, 0} -> Path.join(src, archive_basename_with_version())
      _ -> raise "Fail to tar xfz #{archive}"
    end
  end

  @doc """
  Returns the path of the extracted archive.
  """
  def path_extracted_archive() do
    Path.join(src_path(), archive_basename_with_version())
  end

  @doc """
  Returns the path of the cached results of `make -n` on the `src_path`.
  """
  def path_cached_maken() do
    Path.join(src_path(), "cached_maken.txt")
  end

  @doc """
  Returns the result of `make -n` on the `src_path`.
  """
  def maken!() do
    if File.exists?(path_cached_maken()) do
      File.stream!(path_cached_maken())
    else
      unless executable_exists?("make") do
        raise "make was not found"
      end

      command = "make -n 2>/dev/null"

      result =
        case System.shell(command, cd: path_extracted_archive()) do
          {result, _} -> result |> String.split("\n") |> Stream.filter(& String.match?(&1, ~r|^cc|))
        end

      File.write!(path_cached_maken(), Enum.join(result, "\n"))
      result
    end
  end

  @doc """
  Filters `stream` by matching `string_list`,
  i.e. returns only those elements which matches `string_list`,
  and returns a stream with the given captures as a map.
  """
  def filter_matched_and_named_captures(stream, string_list) do
    r =
      string_list
      |> Enum.map(& "(?<#{&1}>^.*#{&1}.*$)")
      |> Enum.join("|")
      |> Regex.compile!()

    stream
    |> Stream.map(&Regex.named_captures(r, &1))
    |> Stream.reject(&is_nil/1)
    |> Stream.map(&Map.reject(&1, fn {_, v} -> v == "" end))
  end

  @doc """
  Returns the path to include the header of OpenBLAS.
  """
  def include_path() do
    path_extracted_archive()
  end

  @doc """
  Returns incuding option for CFLAGS.
  """
  def including_option() do
    "-I#{include_path()}"
  end

  @doc false
  def make_env() do
    %{
      "ROOT_DIR" => Path.expand("..", __DIR__),
      "BUILD_ARCHIVE" => archive_path_for_build(),
      "BUILD_ARCHIVE_DIR" => build_archive_dir(),
      "SRC_PATH" => src_path()
    }
  end

  defp openblas_cache_dir() do
    if dir = System.get_env("OPENBLAS_CACHE_DIR") do
      Path.expand(dir)
    else
      :filename.basedir(:user_cache, "openblas")
    end
  end

  @doc """
  Returns the source path `src_path`.
  """
  def src_path() do
    Application.app_dir(:openblas_builder, "src")
  end

  defp cache_path(parts) do
    base_dir = openblas_cache_dir()
    Path.join([base_dir, @version, "cache" | parts])
  end

  defp archive_basename_with_version() do
    "OpenBLAS-#{@version}"
  end

  @doc false
  def archive_filename_with_version() do
    "#{archive_basename_with_version()}.tar.gz"
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
