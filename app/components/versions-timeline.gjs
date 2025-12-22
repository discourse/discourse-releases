import Component from '@glimmer/component';
import "./versions-timeline.css";

const eq = (a, b) => a === b;

export default class VersionsTimeline extends Component {
  normalizeDate(dateString) {
    if (!dateString) return dateString;

    // Check if it's yyyy-mm format (month-only, no day)
    if (/^\d{4}-\d{2}$/.test(dateString)) {
      // Get the last day of the month
      const [year, month] = dateString.split('-');
      const lastDay = new Date(parseInt(year), parseInt(month), 0).getDate();
      return `${year}-${month}-${lastDay}`;
    }

    return dateString;
  }

  dateToPercent(date, minDate, totalDays) {
    if (!date) return 0;
    const d = new Date(this.normalizeDate(date));
    const days = (d - minDate) / (1000 * 60 * 60 * 24);
    return (days / totalDays) * 100;
  }

  get chartData() {
    if (!this.args.versions || this.args.versions.length === 0) {
      return null;
    }

    const versions = this.args.versions;

    // Set date range to 10 months before and after today
    const today = new Date();
    const minDate = new Date(today);
    minDate.setMonth(minDate.getMonth() - 10);

    const maxDate = new Date(today);
    maxDate.setMonth(maxDate.getMonth() + 10);

    const totalDays = (maxDate - minDate) / (1000 * 60 * 60 * 24);

    // Generate month markers - show Jan/Apr/Jul/Oct only
    const months = [];
    const current = new Date(minDate);
    current.setDate(1);

    // Start from the first Jan/Apr/Jul/Oct after minDate
    const targetMonths = [0, 3, 6, 9]; // Jan, Apr, Jul, Oct
    while (!targetMonths.includes(current.getMonth())) {
      current.setMonth(current.getMonth() + 1);
    }

    while (current <= maxDate) {
      const percent = this.dateToPercent(current, minDate, totalDays);
      months.push({
        percent,
        month: current.toLocaleDateString('en-US', { month: 'short' }),
        year: current.toLocaleDateString('en-US', { year: 'numeric' })
      });
      current.setMonth(current.getMonth() + 3);
    }

    // Generate version bars
    const bars = versions.map((group, index) => {
      if (!group.headerVersion?.date) return null;

      const startDate = group.headerVersion.date;
      const endDate = group.supportInfo?.supportEndDate;

      const startPercent = this.dateToPercent(startDate, minDate, totalDays);
      let widthPercent;

      if (endDate) {
        const endPercent = this.dateToPercent(endDate, minDate, totalDays);
        widthPercent = endPercent - startPercent;
      } else {
        widthPercent = 100 - startPercent;
      }

      // Use blue for active development, green for supported
      const devColor = '#3498db';
      const supportedColor = '#27ae60';

      // Use development start date from data
      const devStartDate = group.supportInfo?.developmentStartDate || startDate;
      const devStartPercent = this.dateToPercent(devStartDate, minDate, totalDays);
      const devWidthPercent = startPercent - devStartPercent;

      // The remaining part is the "supported" phase
      const supportedStartPercent = startPercent;
      const supportedWidthPercent = widthPercent;

      return {
        version: group.minorVersion,
        startPercent: devStartPercent,
        widthPercent: devWidthPercent + widthPercent,
        devColor,
        supportedColor,
        isESR: group.supportInfo?.isESR,
        status: group.supportInfo?.status,
        devWidthPercent: Math.max(0, devWidthPercent),
        supportedStartPercent,
        supportedWidthPercent: Math.max(0, supportedWidthPercent),
        hasPhases: devWidthPercent > 0 && supportedWidthPercent > 0
      };
    }).filter(Boolean);

    // Calculate today line
    const todayPercent = this.dateToPercent(today, minDate, totalDays);

    return {
      months,
      bars,
      todayPercent
    };
  }

  <template>
    {{#if this.chartData}}
      <div class="timeline-chart">
        <div class="timeline-content-wrapper">
          <div class="timeline-header">
            <div class="timeline-row-label"></div>
            <div class="timeline-timeline">
              {{#each this.chartData.months as |month|}}
                <div
                  class="timeline-month-marker"
                  style="left: {{month.percent}}%"
                >
                  {{month.month}}<br>{{month.year}}
                </div>
              {{/each}}
            </div>
          </div>

          <div class="timeline-body">
          <div class="timeline-rows-wrapper">
            {{#each this.chartData.bars as |bar|}}
              <div class="timeline-row">
                <div class="timeline-row-label">
                  <span class="timeline-status-dot timeline-status-{{bar.status}}"></span>
                  <span class="version-label">v{{bar.version}}</span>
                  {{#if bar.isESR}}
                    <span class="esr-badge {{if (eq bar.status 'end-of-life') 'esr-badge-muted'}}">ESR</span>
                  {{/if}}
                </div>
                <div class="timeline-row-timeline">
                  <a href="#version-{{bar.version}}" class="timeline-bar-link">
                    {{#if bar.hasPhases}}
                      <!-- Active development phase -->
                      <div
                        class="timeline-bar timeline-bar-{{bar.status}} timeline-bar-development"
                        style="left: {{bar.startPercent}}%; width: {{bar.devWidthPercent}}%; background-color: {{bar.devColor}}"
                      ></div>
                      <!-- Supported phase -->
                      <div
                        class="timeline-bar timeline-bar-{{bar.status}} timeline-bar-supported"
                        style="left: {{bar.supportedStartPercent}}%; width: {{bar.supportedWidthPercent}}%; background-color: {{bar.supportedColor}}"
                      ></div>
                    {{else}}
                      <div
                        class="timeline-bar timeline-bar-{{bar.status}}"
                        style="left: {{bar.startPercent}}%; width: {{bar.widthPercent}}%; background-color: {{bar.supportedColor}}"
                      ></div>
                    {{/if}}
                  </a>
                </div>
              </div>
            {{/each}}
          </div>

          <!-- Vertical grid lines -->
          <div class="timeline-grid-wrapper">
            <div class="timeline-grid-spacer"></div>
            <div class="timeline-grid-timeline">
              {{#each this.chartData.months as |month|}}
                <div
                  class="timeline-grid-line"
                  style="left: {{month.percent}}%"
                ></div>
              {{/each}}
            </div>
          </div>

          <!-- Today indicator -->
          <div class="timeline-today-wrapper">
            <div class="timeline-today-spacer"></div>
            <div class="timeline-today-timeline">
              <div
                class="timeline-today-indicator"
                style="left: {{this.chartData.todayPercent}}%"
              >
                <span class="timeline-today-label">Today</span>
                <div class="timeline-today-line"></div>
              </div>
            </div>
          </div>
        </div>
        </div>

        <div class="timeline-legend">
          <div class="timeline-legend-item">
            <div class="timeline-legend-color timeline-legend-color-development"></div>
            <span class="timeline-legend-label">Active Development</span>
          </div>
          <div class="timeline-legend-item">
            <div class="timeline-legend-color timeline-legend-color-supported"></div>
            <span class="timeline-legend-label">Supported</span>
          </div>
        </div>
      </div>
    {{/if}}

  </template>
}
