defmodule Beacon.LiveAdmin.PageNotFound do
  @moduledoc false
  defexception [:message, plug_status: 404]
end

defmodule Beacon.LiveAdmin.PageLive do
  @moduledoc false

  use Beacon.LiveAdmin.Web, :live_view
  alias Beacon.LiveAdmin.PageBuilder.Page
  alias Beacon.LiveAdmin.PageBuilder.Menu
  alias Phoenix.LiveView.Socket

  @impl true
  def mount(params, %{"pages" => pages} = session, socket) do
    request_path = socket.private.connect_info.request_path

    find_page = fn pages ->
      Enum.find(pages, :error, fn {path, _module, _live_action, _opts} -> path == request_path end)
    end

    case find_page.(pages) do
      {path, module, _live_action, page_session} ->
        assign_mount(socket, pages, path, module, page_session, params, session)

      :error ->
        raise Beacon.LiveAdmin.PageNotFound, "unknown page #{inspect(request_path)}"
    end
  end

  defp assign_mount(socket, pages, path, module, page_session, params, _session) do
    socket = assign(socket, page: %Page{module: module}, menu: %Menu{})

    with %Socket{redirected: nil} = socket <- update_page(socket, params: params, path: path),
         %Socket{redirected: nil} = socket <- assign_menu_links(socket, pages) do
      maybe_apply_module(socket, :mount, [params, page_session], &{:ok, &1})
    else
      %Socket{} = redirected_socket -> {:ok, redirected_socket}
    end
  end

  defp assign_menu_links(socket, pages) do
    dbg(pages)
    current_path = socket.assigns.page.path |> dbg

    {links, socket} =
      Enum.map_reduce(pages, socket, fn {path, module, _live_action, session}, socket ->
        current? = path == current_path
        menu_link = module.menu_link(session)

        case {current?, menu_link} do
          {true, {:ok, anchor}} ->
            {{:current, anchor}, socket}

          {true, _} ->
            {:skip, redirect_to_home_page(socket)}

          {false, {:ok, anchor}} ->
            {{:enabled, anchor, path}, socket}

          {false, :skip} ->
            {:skip, socket}

          {false, {:disabled, anchor}} ->
            {{:disabled, anchor}, socket}
        end
      end)

    update_menu(socket, links: links)
  end

  defp redirect_to_home_page(socket) do
    # TODO: live_admin_path
    push_redirect(socket, to: "/")
  end

  defp maybe_apply_module(socket, fun, params, default) do
    if function_exported?(socket.assigns.page.module, fun, length(params) + 1) do
      apply(socket.assigns.page.module, fun, params ++ [socket])
    else
      default.(socket)
    end
  end

  defp update_page(socket, assigns) do
    update(socket, :page, fn page ->
      Enum.reduce(assigns, page, fn {key, value}, page ->
        Map.replace!(page, key, value)
      end)
    end)
  end

  defp update_menu(socket, assigns) do
    update(socket, :menu, fn page ->
      Enum.reduce(assigns, page, fn {key, value}, page ->
        Map.replace!(page, key, value)
      end)
    end)
  end

  defp render_page(module, assigns) do
    module.render(assigns)
  end

  ## Navbar handling

  defp maybe_link(_socket, _page, {:current, text}) do
    assigns = %{text: text}

    ~H"""
    <div class="">
      <%= @text %>
    </div>
    """
  end

  # TODO: prefix path
  defp maybe_link(_socket, _page, {:enabled, text, path}) do
    live_redirect(text,
      to: path,
      class: ""
    )
  end

  defp maybe_link(_socket, _page, {:disabled, text}) do
    assigns = %{text: text}

    ~H"""
    <div class="">
      <%= @text %>
    </div>
    """
  end
end