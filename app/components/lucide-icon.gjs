import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import { createElement } from "lucide";

export default class LucideIcon extends Component {
  get markup() {
    const icon = this.args.icon;
    if (!icon) {
      return;
    }

    const svg = createElement(icon, {
      class: this.args.iconClass ?? "lucide-icon",
      width: this.args.size ?? 16,
      height: this.args.size ?? 16,
      "aria-hidden": "true",
      focusable: "false",
    });

    return svg;
  }

  <template>{{this.markup}}</template>
}
