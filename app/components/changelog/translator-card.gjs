import Component from "@glimmer/component";
import "./translator-card.css";
import { Languages } from "lucide";
import LucideIcon from "../lucide-icon";

export default class TranslatorCard extends Component {
  get thankYouUrl() {
    return `https://translations.discourse.org/thank-you/${this.args.version}`;
  }

  <template>
    <div class="info-card translator-card">
      <span class="translator-card-icon" aria-hidden="true">
        <LucideIcon @icon={{Languages}} @size={{24}} />
      </span>
      <p>
        Thanks to our volunteer translators for their contributions to this
        release!
      </p>
      <a
        href={{this.thankYouUrl}}
        target="_blank"
        rel="noopener noreferrer"
        class="info-card-link"
      >
        Learn more →
      </a>
    </div>
  </template>
}
