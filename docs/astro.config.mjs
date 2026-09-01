// @ts-check
import { defineConfig, fontProviders } from "astro/config";
import starlight from "@astrojs/starlight";

import mermaid from "astro-mermaid";
import catppuccin from "@catppuccin/starlight";

// https://astro.build/config
export default defineConfig({
  experimental: {
    fonts: [
      {
        provider: fontProviders.google(),
        name: "Victor Mono",
        cssVariable: "--sl-font",
      },
    ],
  },
  integrations: [
    mermaid({
      theme: "forest",
      autoTheme: true,
    }),
    starlight({
      title: "flake-file",
      sidebar: [
        {
          label: "flake-file",
          items: [{ label: "Docs Overview", slug: "overview" }],
        },
        {
          label: "Learn",
          items: [
            {
              label: "What is flake-file?",
              slug: "explanation/what-is-flake-file",
            },
            { label: "How it Works", slug: "explanation/how-it-works" },
          ],
        },
        {
          label: "Getting Started",
          items: [
            { label: "Quick Start", slug: "tutorials/quick-start" },
            {
              label: "With Traditional Flake",
              slug: "tutorials/migrate-traditional-flake",
            },
            {
              label: "With Flake Parts",
              slug: "tutorials/migrate-flake-parts",
            },
            { label: "With No Flakes", slug: "tutorials/migrate-no-flakes" },
            { label: "Sandboxed Bootstrap", slug: "tutorials/bootstrap" },
          ],
        },
        {
          label: "Guides",
          items: [
            { label: "flakeModules", slug: "guides/flake-modules" },
            { label: "Templates", slug: "guides/templates" },
            { label: "The outputs Function", slug: "guides/outputs" },
            { label: "Hooks", slug: "guides/hooks" },
            { label: "Automatic Follows", slug: "guides/auto-follow" },
            { label: "Lock Flattening", slug: "guides/lock-flattening" },
            {
              label: "flake-parts-builder",
              slug: "guides/flake-parts-builder",
            },
          ],
        },
        {
          label: "Reference",
          items: [
            { label: "All Options", slug: "reference/options" },
            { label: "Bootstrap Options", slug: "reference/bootstrap" },
          ],
        },
      ],
      components: {
        Sidebar: "./src/components/Sidebar.astro",
        Footer: "./src/components/Footer.astro",
        SocialIcons: "./src/components/SocialIcons.astro",
        PageSidebar: "./src/components/PageSidebar.astro",
      },
      plugins: [
        catppuccin({
          dark: { flavor: "macchiato", accent: "mauve" },
          light: { flavor: "latte", accent: "mauve" },
        }),
      ],
      editLink: {
        baseUrl: "https://github.com/vic/flake-file/edit/main/docs/",
      },
      customCss: ["./src/styles/custom.css"],
    }),
  ],
});
