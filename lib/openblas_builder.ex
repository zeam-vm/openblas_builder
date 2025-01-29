defmodule OpenBLASBuilder do
  @moduledoc """
  Documentation for `OpenBLASBuilder`.
  """

  require Logger

  @github_repo "xianyi/OpenBLAS"
  @version "0.3.29"

  def archive_path!() do
    cond do
      true ->
        path = archive_path_for_matching_download()
        if !File.exists?(path), do: download_matching!(path)
        path
    end
  end

  @doc """
  Extracts the archive of OpenBLAS.
  """
  def extract_archive!() do
    src = src_path()
    File.mkdir_p!(src)
    :erl_tar.extract(archive_path!(), [{:cwd, src}, :keep_old_files, :compressed])
  end

  @doc """
  Returns the path of the extracted archive.
  """
  def path_extracted_archive() do
    Path.join(src_path(), archive_basename_with_version())
  end

  @doc """
  Returns the path of the cached results of `make -n | grep -e "A^cc"` on the `src_path`.
  """
  def path_cached_maken() do
    Path.join(src_path(), "cached_maken.txt")
  end

  @doc """
  Returns the path of the cached results of `make -n | head -1` on the `src_path`.
  """
  def path_cached_maken_head() do
    Path.join(src_path(), "cached_maken_head.txt")
  end

  @doc """
  Returns the result of `make -n` on the `src_path`.
  """
  def maken!() do
    if File.exists?(path_cached_maken()) and File.exists?(path_cached_maken_head()) do
      File.stream!(path_cached_maken())
    else
      if !executable_exists?("make") do
        raise "make was not found"
      end

      command = "make -n 2>/dev/null"

      result =
        case System.shell(command, cd: path_extracted_archive()) do
          {result, _} ->
            s = result |> String.split("\n")

            s
            |> Stream.filter(&String.match?(&1, ~r/^for d/))
            |> Enum.take(1)
            |> hd()
            |> String.split(" ")
            |> Enum.slice(3..-3//-1)
            |> Enum.join("\n")
            |> then(&File.write!(path_cached_maken_head(), &1))

            s |> Stream.filter(&String.match?(&1, ~r|^cc|))
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
      |> Enum.map(&"(?<#{&1}>^.*#{&1}.*$)")
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

  @doc """
  Compiles only files matched by a list of tuples of two strings `{subdir, key}`
  and gets the map from each of a list of strings to the corresponding path to the object file.
  """
  def compile_matched!(list_tuple_two_strings) do
    {list_subdir, list_key} = Enum.unzip(list_tuple_two_strings)

    key_to_subdir =
      Enum.zip(list_key, list_subdir)
      |> Map.new()

    map_key_to_tuple_subdir_command_obj =
      maken!()
      |> filter_matched_and_named_captures(list_key)
      |> Enum.reduce(%{}, fn x, acc -> Map.merge(acc, x) end)
      |> Enum.map(fn {key, command} ->
        subdir = Map.get(key_to_subdir, key)
        obj = Regex.named_captures(~r/-o (?<obj>.+\.o)/, command) |> Map.values() |> hd()

        {
          key,
          {
            subdir,
            command,
            Path.join(subdir, obj)
          }
        }
      end)
      |> Map.new()

    map_key_to_obj =
      map_key_to_tuple_subdir_command_obj
      |> Enum.map(fn {key, {_subdir, _command, obj}} -> {key, obj} end)
      |> Map.new()

    objs =
      Map.values(map_key_to_obj)
      |> Enum.uniq()

    map_key_to_obj =
      map_key_to_obj
      |> Enum.map(fn {key, obj} ->
        {
          key,
          Path.join(path_extracted_archive(), obj)
        }
      end)
      |> Map.new()

    deps =
      map_key_to_tuple_subdir_command_obj
      |> Enum.map(fn {_key, {subdir, command, obj}} ->
        """
        #{obj}:
        \tcd ./#{subdir} && #{command} 2>/dev/null
        """
      end)
      |> Enum.join("\n")

    """
    TOPDIR = .
    include ./Makefile.system

    all: #{Enum.join(objs, " ")}

    #{deps}
    """
    |> then(fn makefile ->
      make = "Makefile.#{:crypto.hash(:sha256, makefile) |> Base.encode16(case: :lower)}"
      File.write!(Path.join(path_extracted_archive(), make), makefile)
      make
    end)
    |> then(&System.shell("make -f #{&1} 2>/dev/null", cd: path_extracted_archive()))
    |> case do
      {_, 0} -> map_key_to_obj
      _ -> %{}
    end
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

    if expected_filename not in filenames do
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
    if !network_tool() do
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
