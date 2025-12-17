import { pageTitle } from 'ember-page-title';
import CommitViewer from '../components/commit-viewer';

<template>
  {{pageTitle "Discourse Commit Viewer"}}

  <CommitViewer
    @start={{@controller.start}}
    @end={{@controller.end}}
    @onUpdateStart={{@controller.updateStart}}
    @onUpdateEnd={{@controller.updateEnd}}
  />

  {{outlet}}
</template>
