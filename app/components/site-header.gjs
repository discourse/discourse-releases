import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import "./site-header.css";
import { Menu, X } from "lucide";
import Logo from "./logo";
import LucideIcon from "./lucide-icon";

const NAV_LINKS = [
  { href: "https://discourse.org", label: "Website ↗" },
  { href: "https://meta.discourse.org", label: "Community ↗" },
  { href: "https://github.com/discourse/discourse", label: "GitHub ↗" },
];

export default class SiteHeader extends Component {
  @tracked menuOpen = false;

  navLinks = NAV_LINKS;

  @action
  toggleMenu() {
    this.menuOpen = !this.menuOpen;
  }

  @action
  closeMenu() {
    this.menuOpen = false;
  }

  <template>
    <header class="site-header">
      <div class="header-content">
        <h1 class="site-title">
          <a href="/" class="title-link" aria-label="Discourse Releases">
            <Logo />
          </a>
        </h1>

        <nav
          class="external-links external-links-desktop"
          aria-label="External links"
        >
          {{#each this.navLinks as |link|}}
            <a
              href={{link.href}}
              class="external-link"
              target="_blank"
              rel="noreferrer"
            >{{link.label}}</a>
          {{/each}}
        </nav>

        <button
          type="button"
          class="site-header-menu-btn"
          aria-label="Open menu"
          aria-expanded={{this.menuOpen}}
          aria-controls="site-header-mobile-menu"
          {{on "click" this.toggleMenu}}
        >
          <LucideIcon @icon={{Menu}} @size={{24}} />
        </button>
      </div>
    </header>

    {{#if this.menuOpen}}
      <div class="site-header-mobile-overlay" id="site-header-mobile-menu">
        <div class="site-header-mobile-top">
          <div class="site-title">
            <a
              href="/"
              class="title-link"
              aria-label="Discourse Releases"
              {{on "click" this.closeMenu}}
            >
              <Logo />
            </a>
          </div>
          <button
            type="button"
            class="site-header-mobile-close"
            aria-label="Close menu"
            {{on "click" this.closeMenu}}
          >
            <LucideIcon @icon={{X}} @size={{24}} />
          </button>
        </div>

        <nav class="site-header-mobile-nav" aria-label="Menu links">
          {{#each this.navLinks as |link|}}
            <a
              href={{link.href}}
              class="site-header-mobile-link"
              target="_blank"
              rel="noreferrer"
              {{on "click" this.closeMenu}}
            >{{link.label}}</a>
          {{/each}}
        </nav>
      </div>
    {{/if}}
  </template>
}
