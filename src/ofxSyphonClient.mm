/*
 *  ofxSyphonServer.cpp
 *  syphonTest
 *
 *  Created by astellato,vade,bangnoise on 11/6/10.
 *  
 *  http://syphon.v002.info/license.php
 */

#include "ofxSyphonClient.h"
#import <Syphon/Syphon.h>
#import "SyphonNameboundClient.h"

ofxSyphonClient::ofxSyphonClient()
{
	bSetup = false;
}

ofxSyphonClient::~ofxSyphonClient()
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    [(SyphonNameboundClient*)mClient release];
    mClient = nil;
    
    [pool drain];
}

void ofxSyphonClient::setup()
{
    // Need pool
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        
	mClient = [[SyphonNameboundClient alloc] init]; 
               
	bSetup = true;
    
    [pool drain];
}

bool ofxSyphonClient::isSetup(){
    return bSetup;
}

void ofxSyphonClient::set(ofxSyphonServerDescription _server){
    set(_server.serverName, _server.appName);
}

void ofxSyphonClient::set(string _serverName, string _appName){
    if(bSetup)
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        
        NSString *nsAppName = [NSString stringWithCString:_appName.c_str() encoding:[NSString defaultCStringEncoding]];
        NSString *nsServerName = [NSString stringWithCString:_serverName.c_str() encoding:[NSString defaultCStringEncoding]];
        
        [(SyphonNameboundClient*)mClient setAppName:nsAppName];
        [(SyphonNameboundClient*)mClient setName:nsServerName];
        
        appName = _appName;
        serverName = _serverName;
        
        [pool drain];
    }
}

void ofxSyphonClient::setApplicationName(string _appName)
{
    if(bSetup)
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        
        NSString *name = [NSString stringWithCString:_appName.c_str() encoding:[NSString defaultCStringEncoding]];
        
        [(SyphonNameboundClient*)mClient setAppName:name];
        
        appName = _appName;

        [pool drain];
    }
    
}
void ofxSyphonClient::setServerName(string _serverName)
{
    if(bSetup)
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        
        NSString *name = [NSString stringWithCString:_serverName.c_str() encoding:[NSString defaultCStringEncoding]];

        if([name length] == 0)
            name = nil;
        
        [(SyphonNameboundClient*)mClient setName:name];
        
        serverName = _serverName;
    
        [pool drain];
    }    
}

string& ofxSyphonClient::getApplicationName(){
    return appName;
}

string& ofxSyphonClient::getServerName(){
    return serverName;
}

void ofxSyphonClient::bind()
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    if(bSetup)
    {
     	[(SyphonNameboundClient*)mClient lockClient];
        SyphonClient *client = [(SyphonNameboundClient*)mClient client];
        
        latestImage = [client newFrameImageForContext:CGLGetCurrentContext()];
		NSSize texSize = [(SyphonImage*)latestImage textureSize];
        
        if(texSize.width && texSize.height)
        {
            // we now have to manually make our ofTexture's ofTextureData a proxy to our SyphonImage
            ofTextureData texData;
            texData.textureTarget = GL_TEXTURE_RECTANGLE_ARB;  // Syphon always outputs rect textures.
            texData.glTypeInternal = GL_RGBA;
            texData.width = texSize.width;
            texData.height = texSize.height;
            texData.tex_w = texSize.width;
            texData.tex_h = texSize.height;
            texData.tex_t = texSize.width;
            texData.tex_u = texSize.height;
            texData.bFlipTexture = YES;
            texData.bAllocated = YES;
            mTex.allocate(texData);
            mTex.setUseExternalTextureID([(SyphonImage*)latestImage textureName]);
            
            mTex.bind();
        }
    }
    else
		cout<<"ofxSyphonClient is not setup, or is not properly connected to server.  Cannot bind.\n";
    
    [pool drain];
}

void ofxSyphonClient::unbind()
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    if(bSetup)
    {
        mTex.unbind();

        [(SyphonNameboundClient*)mClient unlockClient];
        [(SyphonImage*)latestImage release];
        latestImage = nil;
    }
    else
		cout<<"ofxSyphonClient is not setup, or is not properly connected to server.  Cannot unbind.\n";

        [pool drain];
}

void ofxSyphonClient::draw(float x, float y, float w, float h)
{
    this->bind();
    
    if(mTex.isAllocated())
    {
        mTex.draw(x, y, w, h);
    }
    
    this->unbind();
}

void ofxSyphonClient::draw(float x, float y)
{
	this->draw(x, y, mTex.texData.width, mTex.texData.height);
}

void ofxSyphonClient::drawSubsection(float x, float y, float w, float h, float sx, float sy, float sw, float sh)
{
    this->bind();
    
    if(mTex.isAllocated())
    {
        mTex.drawSubsection(x, y, w, h, sx, sy, sw, sh);
    }
    
    this->unbind();
}

void ofxSyphonClient::drawSubsection(float x, float y, float sx, float sy, float sw, float sh)
{
	this->drawSubsection(x, y, mTex.texData.width, mTex.texData.height, sx, sy, sw, sh);
}
void ofxSyphonClient::save(string filename) {
    if(mTex.isAllocated())
    {
        ofPixels pix;
        updateCache();
        mTexCache.readToPixels(pix);
        ofSaveImage(pix, filename);
    }
}

float ofxSyphonClient::getWidth()
{
	return mTex.texData.width;
}

float ofxSyphonClient::getHeight()
{
	return mTex.texData.height;
}

void ofxSyphonClient::updateCache() {
    if(mTex.isAllocated())
    {
        ofFbo::Settings settings;
        settings.width = getWidth();
        settings.height = getHeight();
        settings.numSamples = 0;
        settings.useDepth = false;
        settings.useStencil = false;
        mTexCache.allocate(settings);
        mTexCache.begin();
        ofPushStyle();
        ofClear(0);
        ofSetColor(255);
        mTex.draw(0, 0);
        ofPopStyle();
        mTexCache.end();
    }
}

