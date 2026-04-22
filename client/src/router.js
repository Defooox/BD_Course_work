const routes = [];

export function route(pattern, handler) {
  routes.push({ re: new RegExp('^' + pattern + '$'), handler });
}

export function navigate(hash) {
  window.location.hash = hash;
}

export function initRouter(notFound) {
  async function dispatch() {
    const hash = window.location.hash.replace(/^#/, '') || '/';
    for (const { re, handler } of routes) {
      const m = hash.match(re);
      if (m) {
        await handler(...m.slice(1));
        highlightNav(hash);
        return;
      }
    }
    notFound(hash);
  }

  window.addEventListener('hashchange', dispatch);
  dispatch();
}

function highlightNav(hash) {
  document.querySelectorAll('.nav-link').forEach((a) => {
    a.classList.toggle('active', hash.startsWith(a.getAttribute('href').replace('#', '')));
  });
}
