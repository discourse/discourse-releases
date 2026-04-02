import { pageTitle } from "ember-page-title";
import SiteHeader from "../components/site-header.gjs";

<template>
  {{pageTitle "Discourse Releases"}}
  <div class="app-layout">
    <SiteHeader />

    {{outlet}}
  </div>

  <div class="app-background" aria-hidden="true"></div>
</template>
