import Application from './app/app';
import environment from './app/config/environment';

if(!window.FastBoot){
  Application.create(environment.APP);
}

