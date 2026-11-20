export function App() {
  return (
    <main className="min-h-screen flex flex-col justify-between px-6 py-12 sm:px-12 lg:px-20 bg-stone-50 text-stone-900">
      <header className="max-w-3xl w-full mx-auto flex items-center justify-between border-b border-stone-200 pb-6">
        <span className="font-mono text-sm tracking-tight font-medium text-stone-900">
          genkit-test
        </span>
        <span className="font-mono text-xs text-stone-500">MIT License</span>
      </header>

      <section className="max-w-3xl w-full mx-auto py-16 space-y-6">
        <h1 className="text-4xl sm:text-5xl font-semibold tracking-tight text-stone-950">
          genkit-test
        </h1>
        <p className="text-lg leading-relaxed text-stone-600 max-w-2xl">
          This repository contained only a README, license, and gitignore with no
          application source files. A Vite, React, TypeScript, and Tailwind CSS
          starter has been configured so the development server runs cleanly on
          port 3000.
        </p>
        <div className="pt-4 grid gap-4 sm:grid-cols-3 border-t border-stone-200">
          <div>
            <p className="font-mono text-xs uppercase tracking-wider text-stone-400">
              Entry
            </p>
            <p className="mt-1 font-mono text-sm text-stone-800">src/App.tsx</p>
          </div>
          <div>
            <p className="font-mono text-xs uppercase tracking-wider text-stone-400">
              Styling
            </p>
            <p className="mt-1 font-mono text-sm text-stone-800">
              src/index.css
            </p>
          </div>
          <div>
            <p className="font-mono text-xs uppercase tracking-wider text-stone-400">
              Server
            </p>
            <p className="mt-1 font-mono text-sm text-stone-800">
              0.0.0.0:3000
            </p>
          </div>
        </div>
      </section>

      <footer className="max-w-3xl w-full mx-auto border-t border-stone-200 pt-6 text-xs text-stone-500">
        Ready for your application code.
      </footer>
    </main>
  );
}

export default App;
