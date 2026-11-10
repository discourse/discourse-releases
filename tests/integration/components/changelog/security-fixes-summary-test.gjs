import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import SecurityFixesSummary from "discourse-releases/components/changelog/security-fixes-summary";
import { setupRenderingTest } from "discourse-releases/tests/helpers";

module("Integration | Component | security-fixes-summary", function (hooks) {
  setupRenderingTest(hooks);

  test("shows the CVE ID, or the GHSA ID when there is no CVE", async function (assert) {
    const advisories = [
      {
        cve_id: "CVE-2026-0001",
        ghsa_id: "GHSA-aaaa-bbbb-cccc",
        summary: "With CVE",
        html_url:
          "https://github.com/discourse/discourse/security/advisories/GHSA-aaaa-bbbb-cccc",
      },
      {
        cve_id: null,
        ghsa_id: "GHSA-dddd-eeee-ffff",
        summary: "Without CVE",
        html_url:
          "https://github.com/discourse/discourse/security/advisories/GHSA-dddd-eeee-ffff",
      },
    ];

    await render(
      <template><SecurityFixesSummary @advisories={{advisories}} /></template>
    );
    await click(".summary-header");

    const ids = [...document.querySelectorAll(".advisory-id")].map((el) =>
      el.textContent.trim()
    );
    assert.deepEqual(ids, ["CVE-2026-0001", "GHSA-dddd-eeee-ffff"]);
  });
});
