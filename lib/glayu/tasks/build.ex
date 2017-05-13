defmodule Glayu.Tasks.Build do

  @behaviour Glayu.Tasks.Task

  @max_posts_per_node 100

  alias Glayu.Build.SiteAnalyzer.ContainMdFiles
  alias Glayu.Build.TaskSpawner
  alias Glayu.Build.JobsStore
  alias Glayu.Build.Jobs.RenderPages
  alias Glayu.Build.Jobs.BuildSiteTree
  alias Glayu.Build.Jobs.RenderCategoryPages

  def run(params) do
    nodes = scan_site(params[:regex])
    render_pages(nodes)
    render_category_pages()
    render_home_page()
    copy_assets()
    {:ok, %{results: JobsStore.get_values(RenderPages.__info__(:module))}}
  end

  defp copy_assets() do
    File.cp_r(Glayu.Path.assets_source(), Glayu.Path.public_assets())
  end

  defp scan_site(regex) do
    root = root_dir(regex)
    ProgressBar.render_spinner([text: "Scanning site…", done: [IO.ANSI.light_cyan, "✓", IO.ANSI.reset, " Site scan completed."], frames: :braille, spinner_color: IO.ANSI.light_cyan], fn ->
      nodes = ContainMdFiles.nodes(root, compile_regex(regex))

      sort_fn = fn doc_context1, doc_context2 ->
        comp = DateTime.compare(doc_context1[:date], doc_context2[:date])
        comp == :gt || comp == :eq
      end

      TaskSpawner.spawn(nodes, BuildSiteTree, [sort_fn: sort_fn, num_posts: @max_posts_per_node])
      nodes
    end)
  end

  defp render_pages(nodes) do
    TaskSpawner.spawn(nodes, RenderPages, [])
  end

  defp render_category_pages do
    TaskSpawner.spawn(Glayu.Build.SiteTree.keys(), RenderCategoryPages, [])
  end

  defp render_home_page do
    html = Glayu.HomePage.render()
    Glayu.HomePage.write(html)
  end

  defp compile_regex(nil) do
    nil
  end

  defp compile_regex(regex) do
    Regex.compile!(regex)
  end

  defp root_dir(nil) do
    Glayu.Path.source_root()
  end

  defp root_dir(regex) do
    names = Regex.named_captures(~r/\/(?<path>^[^.^$*+?()[{\|]*$)\//, regex)
    path = names["path"]
    case path do
      nil -> Glayu.Path.source_root
      path -> Path.join(Glayu.Path.source_root, path)
    end
  end

end