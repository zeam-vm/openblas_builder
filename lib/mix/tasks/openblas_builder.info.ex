defmodule Mix.Tasks.OpenblasBuilder.Info do
  @moduledoc """
  Returns relevant information about the OpenBLAS archive.
  """

  use Mix.Task

  @impl true
  def run(["archive_filename"]) do
    Mix.shell().info(OpenBLASBuilder.archive_filename_with_version())
  end

  def run(["release_tag"]) do
    Mix.shell().info(OpenBLASBuilder.release_tag())
  end

  def run(["build_archive_dir"]) do
    Mix.shell().info(OpenBLASBuilder.build_archive_dir())
  end

  def run(_args) do
    Mix.shell().error("""
    Usage:
    mix openblas_builder.info archive_filename
    mix openblas_builder.info release_tag\
    mix openblas_builder.info build_archive_dir\
    """)
  end
end
