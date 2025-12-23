import Application from './app';
import environment from './config/environment';

if(!window.FastBoot){
Application.create(environment.APP);
}

