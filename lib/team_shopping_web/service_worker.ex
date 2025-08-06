defmodule TeamShoppingWeb.ServiceWorker do
  use TeamShoppingWeb, :verified_routes
  use Phoenix.Component
  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    content = """
    const cachableDests = ["image", "style", "manifest", "script"];
    const cacheName = "TeamShoppingCache";

    async function cacheFirst(request) {
      const cachedResponse = await caches.match(request);
      if (cachedResponse) {
        return cachedResponse;
      }
      try {
        const networkResponse = await fetch(request);
        if (networkResponse.ok) {
          console.log(`[Service Worker] Resource fetched from network: ${request.url}`);

          const cache = await caches.open(cacheName);
          cache.put(request, networkResponse.clone());
        }
        return networkResponse;
      } catch (error) {
        console.log(`[Service Worker] Error: ${error}`);
        return Response.error();
      }
    }

    async function netFetch(request) {
      try {
        const networkResponse = await fetch(request);
        if (networkResponse.ok) {
          console.log(`[Service Worker] Resource fetched from network: ${request.url}`);
        }
        return networkResponse;
      } catch (error) {
        console.log(`[Service Worker] Error: ${error}`);
        return Response.error();
      }
    }

    function to_be_cached(request) {
      return cachableDests.includes(request.destination);
    }

    self.addEventListener("fetch", (event) => {
      if (to_be_cached(event.request)) {
        event.respondWith(cacheFirst(event.request));
      } else {
        event.respondWith(netFetch(event.request));
      }
    });

    self.addEventListener('activate', function(event) {
      console.log("[Service Worker] Activated");
      event.waitUntil(self.clients.claim());
    });
    """

    conn
    |> put_resp_header("content-type", "text/javascript")
    |> put_resp_header("cache-control", "public")
    |> put_resp_header("accept-ranges", "bytes")
    |> resp(conn.status || 200, content)
    |> send_resp()
  end
end
